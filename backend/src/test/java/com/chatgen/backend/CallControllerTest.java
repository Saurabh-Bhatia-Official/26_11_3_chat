package com.chatgen.backend;

import com.chatgen.backend.controller.CallController;
import com.chatgen.backend.model.CallSession;
import com.chatgen.backend.model.User;
import com.chatgen.backend.repository.CallSessionRepository;
import com.chatgen.backend.repository.ConversationRepository;
import com.chatgen.backend.repository.MessageRepository;
import com.chatgen.backend.repository.UserRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.mockito.Mockito;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.messaging.simp.SimpMessagingTemplate;

import java.time.Instant;
import java.util.*;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

public class CallControllerTest {

    private CallSessionRepository callSessionRepository;
    private ConversationRepository conversationRepository;
    private MessageRepository messageRepository;
    private UserRepository userRepository;
    private SimpMessagingTemplate messagingTemplate;
    private CallController callController;

    private UUID callerId;
    private UUID receiverId;
    private UUID conversationId;

    @BeforeEach
    void setUp() {
        callSessionRepository = mock(CallSessionRepository.class);
        conversationRepository = mock(ConversationRepository.class);
        messageRepository = mock(MessageRepository.class);
        userRepository = mock(UserRepository.class);
        messagingTemplate = mock(SimpMessagingTemplate.class);

        callController = new CallController(
                callSessionRepository,
                conversationRepository,
                messageRepository,
                userRepository,
                messagingTemplate
        );

        callerId = UUID.randomUUID();
        receiverId = UUID.randomUUID();
        conversationId = UUID.randomUUID();

        User caller = new User();
        caller.setId(callerId);
        caller.setDisplayName("Alice");
        caller.setAvatarUrl("https://example.com/alice.png");

        User receiver = new User();
        receiver.setId(receiverId);
        receiver.setDisplayName("Bob");

        when(userRepository.findById(callerId)).thenReturn(Optional.of(caller));
        when(userRepository.findById(receiverId)).thenReturn(Optional.of(receiver));
    }

    @Test
    void testInitiateCall_Success() {
        when(callSessionRepository.findActiveSessionsForUser(eq(receiverId), anyCollection()))
                .thenReturn(Collections.emptyList());

        when(callSessionRepository.save(any(CallSession.class))).thenAnswer(invocation -> {
            CallSession s = invocation.getArgument(0);
            s.setId(UUID.randomUUID());
            return s;
        });

        Map<String, Object> payload = Map.of(
                "conversationId", conversationId.toString(),
                "callerId", callerId.toString(),
                "receiverId", receiverId.toString(),
                "callType", "VIDEO"
        );

        ResponseEntity<?> response = callController.initiateCall(payload);
        assertEquals(HttpStatus.OK, response.getStatusCode());

        CallSession result = (CallSession) response.getBody();
        assertNotNull(result);
        assertEquals("RINGING", result.getStatus());
        assertEquals("VIDEO", result.getCallType());
        assertEquals("Alice", result.getCallerName());

        verify(messagingTemplate).convertAndSend(eq("/topic/call.user." + receiverId), any(Map.class));
    }

    @Test
    void testInitiateCall_BusyRecipient() {
        CallSession existingCall = new CallSession();
        existingCall.setStatus("CONNECTED");
        when(callSessionRepository.findActiveSessionsForUser(eq(receiverId), anyCollection()))
                .thenReturn(List.of(existingCall));

        when(callSessionRepository.save(any(CallSession.class))).thenAnswer(invocation -> {
            CallSession s = invocation.getArgument(0);
            s.setId(UUID.randomUUID());
            return s;
        });

        Map<String, Object> payload = Map.of(
                "conversationId", conversationId.toString(),
                "callerId", callerId.toString(),
                "receiverId", receiverId.toString(),
                "callType", "AUDIO"
        );

        ResponseEntity<?> response = callController.initiateCall(payload);
        assertEquals(HttpStatus.CONFLICT, response.getStatusCode());

        CallSession result = (CallSession) response.getBody();
        assertNotNull(result);
        assertEquals("BUSY", result.getStatus());
        assertEquals("BUSY", result.getTerminationReason());

        verify(messagingTemplate).convertAndSend(eq("/topic/call.user." + callerId), any(Map.class));
    }

    @Test
    void testAcceptCall() {
        UUID callId = UUID.randomUUID();
        CallSession session = new CallSession();
        session.setId(callId);
        session.setCallerId(callerId);
        session.setReceiverId(receiverId);
        session.setConversationId(conversationId);
        session.setStatus("RINGING");

        when(callSessionRepository.findById(callId)).thenReturn(Optional.of(session));
        when(callSessionRepository.save(any(CallSession.class))).thenAnswer(invocation -> invocation.getArgument(0));

        ResponseEntity<?> response = callController.acceptCall(callId);
        assertEquals(HttpStatus.OK, response.getStatusCode());

        CallSession result = (CallSession) response.getBody();
        assertEquals("ACCEPTED", result.getStatus());
        assertNotNull(result.getAnsweredAt());

        verify(messagingTemplate).convertAndSend(eq("/topic/call.user." + callerId), any(Map.class));
    }

    @Test
    void testRejectCall() {
        UUID callId = UUID.randomUUID();
        CallSession session = new CallSession();
        session.setId(callId);
        session.setCallerId(callerId);
        session.setReceiverId(receiverId);
        session.setConversationId(conversationId);
        session.setStatus("RINGING");

        when(callSessionRepository.findById(callId)).thenReturn(Optional.of(session));
        when(callSessionRepository.save(any(CallSession.class))).thenAnswer(invocation -> invocation.getArgument(0));

        ResponseEntity<?> response = callController.rejectCall(callId);
        assertEquals(HttpStatus.OK, response.getStatusCode());

        CallSession result = (CallSession) response.getBody();
        assertEquals("REJECTED", result.getStatus());
        assertEquals("REJECTED", result.getTerminationReason());
        assertNotNull(result.getEndedAt());
    }

    @Test
    void testCancelCall() {
        UUID callId = UUID.randomUUID();
        CallSession session = new CallSession();
        session.setId(callId);
        session.setCallerId(callerId);
        session.setReceiverId(receiverId);
        session.setConversationId(conversationId);
        session.setStatus("RINGING");

        when(callSessionRepository.findById(callId)).thenReturn(Optional.of(session));
        when(callSessionRepository.save(any(CallSession.class))).thenAnswer(invocation -> invocation.getArgument(0));

        ResponseEntity<?> response = callController.cancelCall(callId);
        assertEquals(HttpStatus.OK, response.getStatusCode());

        CallSession result = (CallSession) response.getBody();
        assertEquals("CANCELLED", result.getStatus());
        assertEquals("CANCELLED", result.getTerminationReason());

        verify(messagingTemplate).convertAndSend(eq("/topic/call.user." + receiverId), any(Map.class));
    }

    @Test
    void testEndCall() {
        UUID callId = UUID.randomUUID();
        CallSession session = new CallSession();
        session.setId(callId);
        session.setCallerId(callerId);
        session.setReceiverId(receiverId);
        session.setConversationId(conversationId);
        session.setCallType("AUDIO");
        session.setStatus("ACCEPTED");
        session.setStartedAt(Instant.now().minusSeconds(45));
        session.setAnsweredAt(Instant.now().minusSeconds(40));

        when(callSessionRepository.findById(callId)).thenReturn(Optional.of(session));
        when(callSessionRepository.save(any(CallSession.class))).thenAnswer(invocation -> invocation.getArgument(0));

        ResponseEntity<?> response = callController.endCall(callId, null);
        assertEquals(HttpStatus.OK, response.getStatusCode());

        CallSession result = (CallSession) response.getBody();
        assertEquals("ENDED", result.getStatus());
        assertTrue(result.getDurationSeconds() >= 39);

        verify(messageRepository).save(any());
        verify(messagingTemplate).convertAndSend(eq("/topic/call.user." + callerId), any(Map.class));
        verify(messagingTemplate).convertAndSend(eq("/topic/call.user." + receiverId), any(Map.class));
    }

    @Test
    void testGetTurnCredentials_GeneratesValidHMAC() {
        ResponseEntity<List<Map<String, Object>>> response = callController.getTurnCredentials("user-123");
        assertEquals(HttpStatus.OK, response.getStatusCode());

        List<Map<String, Object>> iceServers = response.getBody();
        assertNotNull(iceServers);
        assertFalse(iceServers.isEmpty());

        // Check that STUN server is present
        boolean hasStun = iceServers.stream().anyMatch(s -> {
            List<?> urls = (List<?>) s.get("urls");
            return urls != null && urls.get(0).toString().startsWith("stun:");
        });
        assertTrue(hasStun);

        // Check that TURN server with ephemeral credentials is present
        Optional<Map<String, Object>> turnServer = iceServers.stream()
                .filter(s -> s.containsKey("username") && s.containsKey("credential"))
                .findFirst();

        assertTrue(turnServer.isPresent());
        String username = (String) turnServer.get().get("username");
        String credential = (String) turnServer.get().get("credential");

        assertTrue(username.contains(":user-123"));
        assertNotNull(credential);
        assertFalse(credential.isEmpty());
    }

    @Test
    void testHandleWebRtcSignal() {
        Map<String, Object> signal = Map.of(
                "type", "WEBRTC_OFFER",
                "sdp", "v=0...",
                "targetUserId", receiverId.toString(),
                "conversationId", conversationId.toString()
        );

        callController.handleWebRtcSignal(signal);

        verify(messagingTemplate).convertAndSend(eq("/topic/call.user." + receiverId), eq(signal));
        verify(messagingTemplate).convertAndSend(eq("/topic/call." + conversationId), eq(signal));
    }
}
