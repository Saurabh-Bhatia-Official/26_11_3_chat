package com.chatgen.backend;

import com.chatgen.backend.model.Conversation;
import com.chatgen.backend.model.Message;
import com.chatgen.backend.model.User;
import com.chatgen.backend.repository.ConversationRepository;
import com.chatgen.backend.repository.MessageRepository;
import com.chatgen.backend.repository.UserRepository;
import com.chatgen.backend.service.CloudinaryService;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.mock.web.MockMultipartFile;
import org.springframework.test.context.TestPropertySource;

import javax.sql.DataSource;
import java.sql.Connection;
import java.sql.ResultSet;
import java.sql.Statement;
import java.time.Instant;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;

@SpringBootTest
@TestPropertySource(properties = {
    "spring.datasource.url=jdbc:postgresql://aws-0-ap-northeast-1.pooler.supabase.com:5432/postgres?sslmode=require",
    "spring.datasource.username=postgres.vtxwvilrvtiklqmnbenh",
    "spring.datasource.password=JtZfEtX4eX0c8vtJ",
    "spring.jpa.hibernate.ddl-auto=update"
})
public class SupabaseDatabaseIntegrationTest {

    @Autowired
    private DataSource dataSource;

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private ConversationRepository conversationRepository;

    @Autowired
    private MessageRepository messageRepository;

    @Autowired
    private CloudinaryService cloudinaryService;

    @Test
    @DisplayName("1. Verify Direct Supabase PostgreSQL Connection")
    void testSupabaseConnection() throws Exception {
        assertNotNull(dataSource, "DataSource bean should not be null");
        try (Connection conn = dataSource.getConnection()) {
            assertNotNull(conn, "Connection should be established");
            assertTrue(conn.isValid(5), "Connection should be valid");

            try (Statement stmt = conn.createStatement();
                 ResultSet rs = stmt.executeQuery("SELECT current_database(), current_user, version()")) {
                assertTrue(rs.next(), "Query should return result");
                String dbName = rs.getString(1);
                String user = rs.getString(2);
                String version = rs.getString(3);

                System.out.println(">>> Verified Supabase Connection: DB=" + dbName + ", User=" + user + ", Version=" + version);
                assertEquals("postgres", dbName);
                assertEquals("postgres", user);
            }
        }
    }

    @Test
    @DisplayName("2. Verify Supabase User CRUD Operations")
    void testUserCrudOperations() {
        String uniqueSuffix = UUID.randomUUID().toString().substring(0, 8);
        String username = "testuser_" + uniqueSuffix;

        // CREATE
        User user = new User();
        user.setUsername(username);
        user.setDisplayName("Test User " + uniqueSuffix);
        user.setEmail(username + "@whisper.test");
        user.setPassword("SupabaseSecret123!");
        user.setAvatarUrl("https://res.cloudinary.com/dltpal1gr/image/upload/v1/test_avatar.jpg");
        user.setSafetyScore(95);
        user.setStatusMessage("Testing Supabase integration");
        user.setCreatedAt(Instant.now());

        User saved = userRepository.save(user);
        assertNotNull(saved.getId(), "Generated UUID should not be null");

        // READ
        Optional<User> found = userRepository.findById(saved.getId());
        assertTrue(found.isPresent(), "User should be found in Supabase");
        assertEquals(username, found.get().getUsername());

        // UPDATE
        found.get().setStatusMessage("Updated status in Supabase");
        User updated = userRepository.save(found.get());
        assertEquals("Updated status in Supabase", updated.getStatusMessage());

        // DELETE
        userRepository.deleteById(saved.getId());
        Optional<User> deleted = userRepository.findById(saved.getId());
        assertTrue(deleted.isEmpty(), "User should be deleted from Supabase");
    }

    @Test
    @DisplayName("3. Verify Conversation & Message Persistence with Cloudinary Metadata in Supabase")
    void testConversationAndMessageFlow() {
        // Create user first to satisfy foreign key constraint
        User sender = new User();
        sender.setUsername("tester_" + UUID.randomUUID().toString().substring(0, 8));
        sender.setDisplayName("Tester 1");
        sender = userRepository.save(sender);

        // Create conversation
        Conversation conv = new Conversation();
        conv.setTitle("Supabase Integration Test Chat");
        conv.setIsGroup(false);
        conv.setParticipant1Id(sender.getId());
        conv.setParticipant1Name(sender.getDisplayName());
        conv.setParticipant2Id(UUID.randomUUID());
        conv.setParticipant2Name("Tester 2");
        conv.setCreatedAt(Instant.now());
        conv.setLastMessageAt(Instant.now());

        Conversation savedConv = conversationRepository.save(conv);
        assertNotNull(savedConv.getId());

        // Create message referencing Cloudinary asset
        Message msg = new Message();
        msg.setConversationId(savedConv.getId());
        msg.setSenderId(sender.getId());
        msg.setSenderName(sender.getDisplayName());
        msg.setContent("Testing image upload metadata storage in Supabase");
        msg.setType("IMAGE");
        msg.setMediaUrl("https://res.cloudinary.com/dltpal1gr/image/upload/v1729000000/chatgen/attachments/test_image.png");
        msg.setMediaPublicId("chatgen/attachments/test_image");
        msg.setMediaBytes(45678L);
        msg.setCreatedAt(Instant.now());

        Message savedMsg = messageRepository.save(msg);
        assertNotNull(savedMsg.getId());

        // Verify retrieval from Supabase
        Optional<Message> retrieved = messageRepository.findById(savedMsg.getId());
        assertTrue(retrieved.isPresent());
        assertEquals("chatgen/attachments/test_image", retrieved.get().getMediaPublicId());
        assertEquals(45678L, retrieved.get().getMediaBytes());
        assertTrue(retrieved.get().getMediaUrl().contains("cloudinary.com"));

        // Cleanup
        messageRepository.delete(savedMsg);
        conversationRepository.delete(savedConv);
        userRepository.delete(sender);
        assertTrue(messageRepository.findById(savedMsg.getId()).isEmpty());
        assertTrue(conversationRepository.findById(savedConv.getId()).isEmpty());
    }

    @Test
    @DisplayName("4. Verify Cloudinary Upload, Retrieval, and Synchronized Deletion")
    void testCloudinaryFullLifecycle() throws Exception {
        // Valid 1x1 transparent PNG bytes decoded from base64
        byte[] validPngBytes = java.util.Base64.getDecoder().decode(
                "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg=="
        );
        MockMultipartFile file = new MockMultipartFile(
                "file", "integration_test.png", "image/png", validPngBytes
        );

        // Upload to Cloudinary
        Map<String, Object> uploadResult = cloudinaryService.uploadFile(file, "integration_tests");
        assertNotNull(uploadResult);
        String url = (String) uploadResult.get("url");
        String publicId = (String) uploadResult.get("public_id");

        assertNotNull(url, "Cloudinary secure URL must not be null");
        assertNotNull(publicId, "Cloudinary public ID must not be null");
        assertTrue(url.contains("cloudinary.com"), "URL should point to Cloudinary CDN");

        // Verify public ID extraction from URL
        String extractedId = cloudinaryService.extractPublicIdFromUrl(url);
        assertEquals(publicId, extractedId, "Extracted publicId must match returned publicId");

        // Delete from Cloudinary
        boolean deleted = cloudinaryService.deleteFile(publicId);
        assertTrue(deleted, "Asset should be successfully deleted from Cloudinary");
    }
}
