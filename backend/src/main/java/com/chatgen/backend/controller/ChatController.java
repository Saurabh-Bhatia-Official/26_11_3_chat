package com.chatgen.backend.controller;

import com.chatgen.backend.model.Conversation;
import com.chatgen.backend.model.Message;
import com.chatgen.backend.repository.ConversationRepository;
import com.chatgen.backend.repository.MessageRepository;
import com.chatgen.backend.service.SafetyAnalyzerService;
import org.springframework.http.ResponseEntity;
import org.springframework.messaging.handler.annotation.MessageMapping;
import org.springframework.messaging.handler.annotation.Payload;
import org.springframework.messaging.simp.SimpMessagingTemplate;
import org.springframework.web.bind.annotation.*;

import java.time.Instant;
import java.util.*;

@RestController
@RequestMapping("/api/chat")
public class ChatController {

    private final ConversationRepository conversationRepository;
    private final MessageRepository messageRepository;
    private final UserRepository userRepository;
    private final SafetyAnalyzerService safetyAnalyzerService;
    private final SimpMessagingTemplate messagingTemplate;

    public ChatController(ConversationRepository conversationRepository,
                          MessageRepository messageRepository,
                          UserRepository userRepository,
                          SafetyAnalyzerService safetyAnalyzerService,
                          SimpMessagingTemplate messagingTemplate) {
        this.conversationRepository = conversationRepository;
        this.messageRepository = messageRepository;
        this.userRepository = userRepository;
        this.safetyAnalyzerService = safetyAnalyzerService;
        this.messagingTemplate = messagingTemplate;
    }

    @GetMapping("/conversations")
    public ResponseEntity<List<Conversation>> getConversations(@RequestParam(required = false) UUID userId) {
        if (userId != null) {
            List<Conversation> userConvs = conversationRepository.findByParticipant1IdOrParticipant2IdOrderByLastMessageAtDesc(userId, userId);
            if (!userConvs.isEmpty()) {
                return ResponseEntity.ok(userConvs);
            }
        }
        return ResponseEntity.ok(conversationRepository.findAllByOrderByLastMessageAtDesc());
    }

    @PostMapping("/conversations")
    public ResponseEntity<Conversation> createConversation(@RequestBody Conversation conversation) {
        UUID p1 = conversation.getParticipant1Id();
        UUID p2 = conversation.getParticipant2Id();

        // If it's a 1-on-1 chat, check if conversation already exists between p1 and p2
        if (p1 != null && p2 != null && !Boolean.TRUE.equals(conversation.getIsGroup())) {
            Optional<Conversation> existing1 = conversationRepository.findFirstByParticipant1IdAndParticipant2Id(p1, p2);
            if (existing1.isPresent()) return ResponseEntity.ok(existing1.get());

            Optional<Conversation> existing2 = conversationRepository.findFirstByParticipant1IdAndParticipant2Id(p2, p1);
            if (existing2.isPresent()) return ResponseEntity.ok(existing2.get());
        }

        conversation.setCreatedAt(Instant.now());
        conversation.setLastMessageAt(Instant.now());
        Conversation saved = conversationRepository.save(conversation);
        return ResponseEntity.ok(saved);
    }

    @GetMapping("/conversations/{id}/messages")
    public ResponseEntity<List<Message>> getMessages(@PathVariable UUID id) {
        return ResponseEntity.ok(messageRepository.findByConversationIdOrderByCreatedAtAsc(id));
    }

    @PostMapping("/conversations/{id}/messages")
    public ResponseEntity<Message> sendMessageRest(@PathVariable UUID id, @RequestBody Message message) {
        message.setConversationId(id);
        Message saved = processAndSaveMessage(message);
        return ResponseEntity.ok(saved);
    }

    @MessageMapping("/chat.sendMessage")
    public void sendMessageWebSocket(@Payload Message message) {
        Message saved = processAndSaveMessage(message);
        messagingTemplate.convertAndSend("/topic/conversation." + saved.getConversationId(), saved);
    }

    @MessageMapping("/chat.typing")
    public void handleTyping(@Payload Map<String, Object> typingEvent) {
        String conversationId = (String) typingEvent.get("conversationId");
        if (conversationId != null) {
            messagingTemplate.convertAndSend("/topic/conversation." + conversationId + ".typing", typingEvent);
        }
    }

    @MessageMapping("/chat.callSignal")
    public void handleCallSignal(@Payload Map<String, Object> signal) {
        String conversationId = (String) signal.get("conversationId");
        if (conversationId != null) {
            messagingTemplate.convertAndSend("/topic/call." + conversationId, signal);
        }
    }

    private Message processAndSaveMessage(Message message) {
        message.setCreatedAt(Instant.now());

        if (message.getSenderAvatarUrl() == null || message.getSenderAvatarUrl().isBlank()) {
            if (message.getSenderId() != null) {
                userRepository.findById(message.getSenderId()).ifPresent(u -> {
                    message.setSenderAvatarUrl(u.getAvatarUrl());
                    if (message.getSenderName() == null || message.getSenderName().isBlank()) {
                        message.setSenderName(u.getDisplayName());
                    }
                });
            }
        }

        // Run Smart Safety Guardian link detection on message text
        if (message.getContent() != null && !message.getContent().isBlank()) {
            Map<String, Object> safetyReport = safetyAnalyzerService.analyzeContentSafety(
                    message.getSenderId(), message.getContent()
            );
            if ((boolean) safetyReport.get("hasThreat")) {
                message.setSafetyFlagged(true);
            }
        }

        Message saved = messageRepository.save(message);

        // Update conversation last message preview
        conversationRepository.findById(message.getConversationId()).ifPresent(conv -> {
            conv.setLastMessagePreview(message.getContent());
            conv.setLastMessageAt(Instant.now());
            conversationRepository.save(conv);
        });

        return saved;
    }
}
