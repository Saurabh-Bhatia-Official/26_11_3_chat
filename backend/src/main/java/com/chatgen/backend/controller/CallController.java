package com.chatgen.backend.controller;

import com.chatgen.backend.model.CallSession;
import com.chatgen.backend.model.Message;
import com.chatgen.backend.repository.CallSessionRepository;
import com.chatgen.backend.repository.ConversationRepository;
import com.chatgen.backend.repository.MessageRepository;
import com.chatgen.backend.repository.UserRepository;
import org.springframework.http.ResponseEntity;
import org.springframework.messaging.handler.annotation.MessageMapping;
import org.springframework.messaging.handler.annotation.Payload;
import org.springframework.messaging.simp.SimpMessagingTemplate;
import org.springframework.web.bind.annotation.*;

import java.time.Duration;
import java.time.Instant;
import java.util.*;

@RestController
@RequestMapping("/api/calls")
public class CallController {

    private final CallSessionRepository callSessionRepository;
    private final ConversationRepository conversationRepository;
    private final MessageRepository messageRepository;
    private final UserRepository userRepository;
    private final SimpMessagingTemplate messagingTemplate;

    public CallController(CallSessionRepository callSessionRepository,
                          ConversationRepository conversationRepository,
                          MessageRepository messageRepository,
                          UserRepository userRepository,
                          SimpMessagingTemplate messagingTemplate) {
        this.callSessionRepository = callSessionRepository;
        this.conversationRepository = conversationRepository;
        this.messageRepository = messageRepository;
        this.userRepository = userRepository;
        this.messagingTemplate = messagingTemplate;
    }

    @PostMapping("/initiate")
    public ResponseEntity<?> initiateCall(@RequestBody Map<String, Object> payload) {
        UUID conversationId = UUID.fromString(payload.get("conversationId").toString());
        UUID callerId = UUID.fromString(payload.get("callerId").toString());
        UUID receiverId = UUID.fromString(payload.get("receiverId").toString());
        String callType = payload.getOrDefault("callType", "AUDIO").toString().toUpperCase();

        CallSession session = new CallSession();
        session.setConversationId(conversationId);
        session.setCallerId(callerId);
        session.setReceiverId(receiverId);
        session.setCallType(callType);
        session.setStatus("RINGING");
        session.setStartedAt(Instant.now());

        userRepository.findById(callerId).ifPresent(u -> {
            session.setCallerName(u.getDisplayName());
            session.setCallerAvatarUrl(u.getAvatarUrl());
        });
        userRepository.findById(receiverId).ifPresent(u -> {
            session.setReceiverName(u.getDisplayName());
        });

        CallSession saved = callSessionRepository.save(session);

        // Real-time signaling push to receiver and conversation
        Map<String, Object> signal = new HashMap<>();
        signal.put("type", "CALL_INITIATE");
        signal.put("callSession", saved);
        signal.put("conversationId", conversationId.toString());

        try {
            messagingTemplate.convertAndSend("/topic/call.user." + receiverId, signal);
            messagingTemplate.convertAndSend("/topic/call." + conversationId, signal);
        } catch (Exception ignored) {}

        return ResponseEntity.ok(saved);
    }

    @PostMapping("/{id}/accept")
    public ResponseEntity<?> acceptCall(@PathVariable UUID id) {
        return callSessionRepository.findById(id).map(session -> {
            session.setStatus("ACCEPTED");
            session.setStartedAt(Instant.now());
            CallSession saved = callSessionRepository.save(session);

            Map<String, Object> signal = new HashMap<>();
            signal.put("type", "CALL_ACCEPT");
            signal.put("callSession", saved);
            signal.put("conversationId", saved.getConversationId().toString());

            try {
                messagingTemplate.convertAndSend("/topic/call.user." + saved.getCallerId(), signal);
                messagingTemplate.convertAndSend("/topic/call." + saved.getConversationId(), signal);
            } catch (Exception ignored) {}

            return ResponseEntity.ok(saved);
        }).orElse(ResponseEntity.notFound().build());
    }

    @PostMapping("/{id}/reject")
    public ResponseEntity<?> rejectCall(@PathVariable UUID id) {
        return callSessionRepository.findById(id).map(session -> {
            session.setStatus("REJECTED");
            session.setEndedAt(Instant.now());
            CallSession saved = callSessionRepository.save(session);

            Map<String, Object> signal = new HashMap<>();
            signal.put("type", "CALL_REJECT");
            signal.put("callSession", saved);
            signal.put("conversationId", saved.getConversationId().toString());

            try {
                messagingTemplate.convertAndSend("/topic/call.user." + saved.getCallerId(), signal);
                messagingTemplate.convertAndSend("/topic/call." + saved.getConversationId(), signal);
            } catch (Exception ignored) {}

            return ResponseEntity.ok(saved);
        }).orElse(ResponseEntity.notFound().build());
    }

    @PostMapping("/{id}/end")
    public ResponseEntity<?> endCall(@PathVariable UUID id, @RequestBody(required = false) Map<String, Object> payload) {
        return callSessionRepository.findById(id).map(session -> {
            session.setStatus("ENDED");
            Instant now = Instant.now();
            session.setEndedAt(now);
            if (session.getStartedAt() != null) {
                int duration = (int) Duration.between(session.getStartedAt(), now).getSeconds();
                session.setDurationSeconds(Math.max(0, duration));
            }
            CallSession saved = callSessionRepository.save(session);

            // Record system message in chat
            int dur = saved.getDurationSeconds();
            String durStr = String.format("%02d:%02d", dur / 60, dur % 60);
            String icon = "VIDEO".equalsIgnoreCase(saved.getCallType()) ? "🎥 Video call" : "📞 Audio call";
            Message sysMsg = new Message();
            sysMsg.setConversationId(saved.getConversationId());
            sysMsg.setSenderId(saved.getCallerId());
            sysMsg.setSenderName("System");
            sysMsg.setContent(icon + " ended • " + durStr);
            sysMsg.setType("SYSTEM");
            sysMsg.setCreatedAt(Instant.now());
            messageRepository.save(sysMsg);

            Map<String, Object> signal = new HashMap<>();
            signal.put("type", "CALL_END");
            signal.put("callSession", saved);
            signal.put("conversationId", saved.getConversationId().toString());

            try {
                messagingTemplate.convertAndSend("/topic/call.user." + saved.getCallerId(), signal);
                messagingTemplate.convertAndSend("/topic/call.user." + saved.getReceiverId(), signal);
                messagingTemplate.convertAndSend("/topic/call." + saved.getConversationId(), signal);
                messagingTemplate.convertAndSend("/topic/conversation." + saved.getConversationId(), sysMsg);
            } catch (Exception ignored) {}

            return ResponseEntity.ok(saved);
        }).orElse(ResponseEntity.notFound().build());
    }

    @GetMapping("/ice-servers")
    public ResponseEntity<List<Map<String, Object>>> getIceServers() {
        List<Map<String, Object>> iceServers = new ArrayList<>();

        // Google STUN
        Map<String, Object> stun1 = new HashMap<>();
        stun1.put("urls", List.of("stun:stun.l.google.com:19302", "stun:stun1.l.google.com:19302"));
        iceServers.add(stun1);

        // Twilio Global STUN
        Map<String, Object> stun2 = new HashMap<>();
        stun2.put("urls", List.of("stun:global.stun.twilio.com:3478"));
        iceServers.add(stun2);

        // Turn server hook (configured via env variables if provided in production)
        String turnUrl = System.getenv("TURN_SERVER_URL");
        if (turnUrl != null && !turnUrl.isBlank()) {
            Map<String, Object> turn = new HashMap<>();
            turn.put("urls", List.of(turnUrl));
            turn.put("username", System.getenv().getOrDefault("TURN_USERNAME", "chatgen"));
            turn.put("credential", System.getenv().getOrDefault("TURN_CREDENTIAL", "chatgen_pass"));
            iceServers.add(turn);
        }

        return ResponseEntity.ok(iceServers);
    }

    @GetMapping("/history")
    public ResponseEntity<List<CallSession>> getCallHistory(@RequestParam String userId) {
        try {
            UUID uid = UUID.fromString(userId);
            return ResponseEntity.ok(callSessionRepository.findByCallerIdOrReceiverIdOrderByCreatedAtDesc(uid, uid));
        } catch (Exception e) {
            return ResponseEntity.badRequest().build();
        }
    }

    @MessageMapping("/call.signal")
    public void handleWebRtcSignal(@Payload Map<String, Object> signal) {
        String targetUserId = (String) signal.get("targetUserId");
        String conversationId = (String) signal.get("conversationId");
        if (targetUserId != null) {
            messagingTemplate.convertAndSend("/topic/call.user." + targetUserId, signal);
        } else if (conversationId != null) {
            messagingTemplate.convertAndSend("/topic/call." + conversationId, signal);
        }
    }
}
