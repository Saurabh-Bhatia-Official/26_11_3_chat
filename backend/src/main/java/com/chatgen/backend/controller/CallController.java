package com.chatgen.backend.controller;

import com.chatgen.backend.model.CallSession;
import com.chatgen.backend.model.Message;
import com.chatgen.backend.repository.CallSessionRepository;
import com.chatgen.backend.repository.ConversationRepository;
import com.chatgen.backend.repository.MessageRepository;
import com.chatgen.backend.repository.UserRepository;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.messaging.handler.annotation.MessageMapping;
import org.springframework.messaging.handler.annotation.Payload;
import org.springframework.messaging.simp.SimpMessagingTemplate;
import org.springframework.web.bind.annotation.*;

import javax.crypto.Mac;
import javax.crypto.spec.SecretKeySpec;
import java.nio.charset.StandardCharsets;
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

    /**
     * Initiate a real-time audio or video call session.
     * Prevents duplicate/conflicting calls if the recipient is already in a call.
     */
    @PostMapping(value = {"", "/initiate"})
    public ResponseEntity<?> initiateCall(@RequestBody Map<String, Object> payload) {
        if (payload.get("conversationId") == null || payload.get("callerId") == null || payload.get("receiverId") == null) {
            return ResponseEntity.badRequest().body(Map.of("error", "conversationId, callerId, and receiverId are required"));
        }

        UUID conversationId = UUID.fromString(payload.get("conversationId").toString());
        UUID callerId = UUID.fromString(payload.get("callerId").toString());
        UUID receiverId = UUID.fromString(payload.get("receiverId").toString());
        String callType = payload.getOrDefault("callType", "AUDIO").toString().toUpperCase();

        // 1. Check if recipient is already in an active call (RINGING, ACCEPTED, CONNECTED)
        List<CallSession> activeSessions = callSessionRepository.findActiveSessionsForUser(
                receiverId, List.of("RINGING", "ACCEPTED", "CONNECTED"));

        if (!activeSessions.isEmpty()) {
            CallSession busySession = new CallSession();
            busySession.setConversationId(conversationId);
            busySession.setCallerId(callerId);
            busySession.setReceiverId(receiverId);
            busySession.setCallType(callType);
            busySession.setStatus("BUSY");
            busySession.setTerminationReason("BUSY");
            busySession.setStartedAt(Instant.now());
            busySession.setEndedAt(Instant.now());

            userRepository.findById(callerId).ifPresent(u -> {
                busySession.setCallerName(u.getDisplayName());
                busySession.setCallerAvatarUrl(u.getAvatarUrl());
            });
            userRepository.findById(receiverId).ifPresent(u -> {
                busySession.setReceiverName(u.getDisplayName());
            });

            CallSession savedBusy = callSessionRepository.save(busySession);

            Map<String, Object> busySignal = new HashMap<>();
            busySignal.put("type", "CALL_BUSY");
            busySignal.put("callSession", savedBusy);
            busySignal.put("message", "User is currently busy on another call");
            busySignal.put("conversationId", conversationId.toString());

            try {
                messagingTemplate.convertAndSend("/topic/call.user." + callerId, busySignal);
            } catch (Exception ignored) {}

            return ResponseEntity.status(HttpStatus.CONFLICT).body(savedBusy);
        }

        // 2. Create new active CallSession
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

        // 3. Dispatch real-time CALL_INCOMING and CALL_INITIATE signaling events
        Map<String, Object> signal = new HashMap<>();
        signal.put("type", "CALL_INCOMING");
        signal.put("callSession", saved);
        signal.put("conversationId", conversationId.toString());

        try {
            messagingTemplate.convertAndSend("/topic/call.user." + receiverId, signal);
            messagingTemplate.convertAndSend("/topic/call." + conversationId, signal);
        } catch (Exception ignored) {}

        return ResponseEntity.ok(saved);
    }

    /**
     * Accept an incoming call.
     */
    @PostMapping("/{id}/accept")
    public ResponseEntity<?> acceptCall(@PathVariable UUID id) {
        return callSessionRepository.findById(id).map(session -> {
            session.setStatus("ACCEPTED");
            Instant now = Instant.now();
            session.setAnsweredAt(now);
            if (session.getStartedAt() == null) {
                session.setStartedAt(now);
            }
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

    /**
     * Reject an incoming call.
     */
    @PostMapping("/{id}/reject")
    public ResponseEntity<?> rejectCall(@PathVariable UUID id) {
        return callSessionRepository.findById(id).map(session -> {
            session.setStatus("REJECTED");
            session.setTerminationReason("REJECTED");
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

    /**
     * Cancel an outgoing call before it is answered.
     */
    @PostMapping("/{id}/cancel")
    public ResponseEntity<?> cancelCall(@PathVariable UUID id) {
        return callSessionRepository.findById(id).map(session -> {
            session.setStatus("CANCELLED");
            session.setTerminationReason("CANCELLED");
            session.setEndedAt(Instant.now());
            CallSession saved = callSessionRepository.save(session);

            Map<String, Object> signal = new HashMap<>();
            signal.put("type", "CALL_CANCEL");
            signal.put("callSession", saved);
            signal.put("conversationId", saved.getConversationId().toString());

            try {
                messagingTemplate.convertAndSend("/topic/call.user." + saved.getReceiverId(), signal);
                messagingTemplate.convertAndSend("/topic/call." + saved.getConversationId(), signal);
            } catch (Exception ignored) {}

            return ResponseEntity.ok(saved);
        }).orElse(ResponseEntity.notFound().build());
    }

    /**
     * Handle unanswered call timeout.
     */
    @PostMapping("/{id}/timeout")
    public ResponseEntity<?> timeoutCall(@PathVariable UUID id) {
        return callSessionRepository.findById(id).map(session -> {
            session.setStatus("MISSED");
            session.setTerminationReason("TIMEOUT");
            session.setEndedAt(Instant.now());
            CallSession saved = callSessionRepository.save(session);

            Map<String, Object> signal = new HashMap<>();
            signal.put("type", "CALL_TIMEOUT");
            signal.put("callSession", saved);
            signal.put("conversationId", saved.getConversationId().toString());

            try {
                messagingTemplate.convertAndSend("/topic/call.user." + saved.getCallerId(), signal);
                messagingTemplate.convertAndSend("/topic/call.user." + saved.getReceiverId(), signal);
                messagingTemplate.convertAndSend("/topic/call." + saved.getConversationId(), signal);
            } catch (Exception ignored) {}

            return ResponseEntity.ok(saved);
        }).orElse(ResponseEntity.notFound().build());
    }

    /**
     * End an ongoing call. Records duration and updates chat history with a system message.
     */
    @PostMapping("/{id}/end")
    public ResponseEntity<?> endCall(@PathVariable UUID id, @RequestBody(required = false) Map<String, Object> payload) {
        return callSessionRepository.findById(id).map(session -> {
            session.setStatus("ENDED");
            if (session.getTerminationReason() == null) {
                session.setTerminationReason("NORMAL");
            }
            Instant now = Instant.now();
            session.setEndedAt(now);

            // Compute call duration from answer time, or started time
            Instant startTime = session.getAnsweredAt() != null ? session.getAnsweredAt() : session.getStartedAt();
            if (startTime != null) {
                int duration = (int) Duration.between(startTime, now).getSeconds();
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

    /**
     * Retrieve a specific call session by ID.
     */
    @GetMapping("/{id}")
    public ResponseEntity<?> getCallSession(@PathVariable UUID id) {
        return callSessionRepository.findById(id)
                .map(ResponseEntity::ok)
                .orElse(ResponseEntity.notFound().build());
    }

    /**
     * Retrieve active ringing or connected call for a given user.
     */
    @GetMapping("/active")
    public ResponseEntity<?> getActiveCall(@RequestParam String userId) {
        try {
            UUID uid = UUID.fromString(userId);
            List<CallSession> active = callSessionRepository.findActiveSessionsForUser(
                    uid, List.of("RINGING", "ACCEPTED", "CONNECTED"));
            if (!active.isEmpty()) {
                return ResponseEntity.ok(active.get(0));
            }
            return ResponseEntity.ok(Collections.emptyMap());
        } catch (Exception e) {
            return ResponseEntity.badRequest().body(Map.of("error", "Invalid user ID format"));
        }
    }

    /**
     * Self-Hosted coturn STUN/TURN ephemeral credential generation.
     * Complies with the standard TURN REST API algorithm (RFC 7635):
     * Generates a 24-hour expiring HMAC-SHA1 signature using COTURN_SECRET.
     * Permanent credentials are never exposed to the frontend.
     */
    @GetMapping(value = {"/turn-credentials", "/ice-servers"})
    public ResponseEntity<List<Map<String, Object>>> getTurnCredentials(@RequestParam(required = false) String userId) {
        List<Map<String, Object>> iceServers = new ArrayList<>();

        String coturnHost = System.getenv().getOrDefault("COTURN_HOST", "turn.whisper.chat");
        String coturnPort = System.getenv().getOrDefault("COTURN_PORT", "3478");
        String coturnTlsPort = System.getenv().getOrDefault("COTURN_TLS_PORT", "5349");
        String coturnSecret = System.getenv().getOrDefault("COTURN_SECRET", "whisper_turn_secret_secure_key_2026");

        // 1. Primary Self-Hosted Coturn STUN
        Map<String, Object> selfStun = new HashMap<>();
        selfStun.put("urls", List.of("stun:" + coturnHost + ":" + coturnPort));
        iceServers.add(selfStun);

        // 2. Ephemeral TURN Credentials (expires in 24 hours)
        long expiryTimestamp = Instant.now().getEpochSecond() + 86400; // 24h expiration
        String safeUser = (userId != null && !userId.isBlank()) ? userId : UUID.randomUUID().toString().substring(0, 8);
        String ephemeralUsername = expiryTimestamp + ":" + safeUser;
        String ephemeralPassword = calculateHmacSha1(ephemeralUsername, coturnSecret);

        if (ephemeralPassword != null && !ephemeralPassword.isEmpty()) {
            // UDP Relay Server
            Map<String, Object> turnUdp = new HashMap<>();
            turnUdp.put("urls", List.of("turn:" + coturnHost + ":" + coturnPort + "?transport=udp"));
            turnUdp.put("username", ephemeralUsername);
            turnUdp.put("credential", ephemeralPassword);
            iceServers.add(turnUdp);

            // TCP Relay Server (for restrictive firewalls blocking UDP)
            Map<String, Object> turnTcp = new HashMap<>();
            turnTcp.put("urls", List.of("turn:" + coturnHost + ":" + coturnPort + "?transport=tcp"));
            turnTcp.put("username", ephemeralUsername);
            turnTcp.put("credential", ephemeralPassword);
            iceServers.add(turnTcp);

            // Secure TLS Relay Server (port 5349)
            Map<String, Object> turnTls = new HashMap<>();
            turnTls.put("urls", List.of("turns:" + coturnHost + ":" + coturnTlsPort + "?transport=tcp"));
            turnTls.put("username", ephemeralUsername);
            turnTls.put("credential", ephemeralPassword);
            iceServers.add(turnTls);
        }

        // 3. Fallback standard STUN for resilient direct peer connectivity
        Map<String, Object> fallbackStun = new HashMap<>();
        fallbackStun.put("urls", List.of("stun:stun.l.google.com:19302"));
        iceServers.add(fallbackStun);

        return ResponseEntity.ok(iceServers);
    }

    /**
     * Retrieve complete call history for a user.
     */
    @GetMapping("/history")
    public ResponseEntity<List<CallSession>> getCallHistory(@RequestParam String userId) {
        try {
            UUID uid = UUID.fromString(userId);
            return ResponseEntity.ok(callSessionRepository.findByCallerIdOrReceiverIdOrderByCreatedAtDesc(uid, uid));
        } catch (Exception e) {
            return ResponseEntity.badRequest().build();
        }
    }

    /**
     * Real-time WebRTC WebSocket signaling relay.
     * Routes SDP Offers, SDP Answers, ICE Candidates, and Call Lifecycle events.
     */
    @MessageMapping("/call.signal")
    public void handleWebRtcSignal(@Payload Map<String, Object> signal) {
        if (signal == null) return;

        String targetUserId = (String) signal.get("targetUserId");
        String conversationId = (String) signal.get("conversationId");

        // Validate event types
        String type = (String) signal.get("type");
        if (type == null) return;

        if (targetUserId != null && !targetUserId.isBlank()) {
            messagingTemplate.convertAndSend("/topic/call.user." + targetUserId, signal);
        }
        if (conversationId != null && !conversationId.isBlank()) {
            messagingTemplate.convertAndSend("/topic/call." + conversationId, signal);
        }
    }

    /**
     * Standard HMAC-SHA1 calculation for TURN REST API authentication (RFC 7635).
     */
    private String calculateHmacSha1(String data, String key) {
        try {
            SecretKeySpec signingKey = new SecretKeySpec(key.getBytes(StandardCharsets.UTF_8), "HmacSHA1");
            Mac mac = Mac.getInstance("HmacSHA1");
            mac.init(signingKey);
            byte[] rawHmac = mac.doFinal(data.getBytes(StandardCharsets.UTF_8));
            return Base64.getEncoder().encodeToString(rawHmac);
        } catch (Exception e) {
            return null;
        }
    }
}
