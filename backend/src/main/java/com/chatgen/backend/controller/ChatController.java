package com.chatgen.backend.controller;

import com.chatgen.backend.model.Conversation;
import com.chatgen.backend.model.Message;
import com.chatgen.backend.repository.ConversationRepository;
import com.chatgen.backend.repository.MessageRepository;
import com.chatgen.backend.repository.UserRepository;
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
        List<Conversation> list;
        if (userId != null) {
            list = conversationRepository.findByParticipant1IdOrParticipant2IdOrderByLastMessageAtDesc(userId, userId);
            if (list.isEmpty()) {
                list = conversationRepository.findAllByOrderByLastMessageAtDesc();
            }
        } else {
            list = conversationRepository.findAllByOrderByLastMessageAtDesc();
        }

        List<Conversation> formatted = new ArrayList<>();
        for (Conversation conv : list) {
            ensureParticipantMetadata(conv);
            formatted.add(formatForViewer(conv, userId));
        }
        return ResponseEntity.ok(formatted);
    }

    @PostMapping("/conversations")
    public ResponseEntity<Conversation> createConversation(@RequestBody Conversation conversation) {
        UUID p1 = conversation.getParticipant1Id();
        UUID p2 = conversation.getParticipant2Id();

        // If it's a 1-on-1 chat, check if conversation already exists between p1 and p2
        if (p1 != null && p2 != null && !Boolean.TRUE.equals(conversation.getIsGroup())) {
            Optional<Conversation> existing1 = conversationRepository.findFirstByParticipant1IdAndParticipant2Id(p1, p2);
            if (existing1.isPresent()) {
                Conversation c = existing1.get();
                ensureParticipantMetadata(c);
                return ResponseEntity.ok(formatForViewer(c, conversation.getCreatedBy()));
            }

            Optional<Conversation> existing2 = conversationRepository.findFirstByParticipant1IdAndParticipant2Id(p2, p1);
            if (existing2.isPresent()) {
                Conversation c = existing2.get();
                ensureParticipantMetadata(c);
                return ResponseEntity.ok(formatForViewer(c, conversation.getCreatedBy()));
            }
        }

        if (conversation.getParticipant1Id() != null && conversation.getParticipant1Name() == null) {
            userRepository.findById(conversation.getParticipant1Id()).ifPresent(u -> {
                conversation.setParticipant1Name(u.getDisplayName());
                if (conversation.getParticipant1Avatar() == null) {
                    conversation.setParticipant1Avatar(u.getAvatarUrl());
                }
            });
        }
        if (conversation.getParticipant2Id() != null && conversation.getParticipant2Name() == null) {
            userRepository.findById(conversation.getParticipant2Id()).ifPresent(u -> {
                conversation.setParticipant2Name(u.getDisplayName());
                if (conversation.getParticipant2Avatar() == null) {
                    conversation.setParticipant2Avatar(u.getAvatarUrl());
                }
            });
        }

        conversation.setCreatedAt(Instant.now());
        conversation.setLastMessageAt(Instant.now());
        Conversation saved = conversationRepository.save(conversation);
        return ResponseEntity.ok(formatForViewer(saved, conversation.getCreatedBy()));
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
            ensureParticipantMetadata(conv);
            conversationRepository.save(conv);
        });

        return saved;
    }

    private void ensureParticipantMetadata(Conversation conv) {
        boolean changed = false;
        if (conv.getParticipant1Id() != null && (conv.getParticipant1Name() == null || conv.getParticipant1Avatar() == null)) {
            var uOpt = userRepository.findById(conv.getParticipant1Id());
            if (uOpt.isPresent()) {
                var u = uOpt.get();
                if (conv.getParticipant1Name() == null) conv.setParticipant1Name(u.getDisplayName());
                if (conv.getParticipant1Avatar() == null) conv.setParticipant1Avatar(u.getAvatarUrl());
                changed = true;
            }
        }
        if (conv.getParticipant2Id() != null && (conv.getParticipant2Name() == null || conv.getParticipant2Avatar() == null)) {
            var uOpt = userRepository.findById(conv.getParticipant2Id());
            if (uOpt.isPresent()) {
                var u = uOpt.get();
                if (conv.getParticipant2Name() == null) conv.setParticipant2Name(u.getDisplayName());
                if (conv.getParticipant2Avatar() == null) conv.setParticipant2Avatar(u.getAvatarUrl());
                changed = true;
            }
        }
        if (changed) {
            conversationRepository.save(conv);
        }
    }

    private Conversation formatForViewer(Conversation source, UUID viewerId) {
        if (Boolean.TRUE.equals(source.getIsGroup()) || viewerId == null) {
            return source;
        }
        Conversation copy = new Conversation();
        copy.setId(source.getId());
        copy.setIsGroup(source.getIsGroup());
        copy.setCreatedBy(source.getCreatedBy());
        copy.setParticipant1Id(source.getParticipant1Id());
        copy.setParticipant1Name(source.getParticipant1Name());
        copy.setParticipant1Avatar(source.getParticipant1Avatar());
        copy.setParticipant2Id(source.getParticipant2Id());
        copy.setParticipant2Name(source.getParticipant2Name());
        copy.setParticipant2Avatar(source.getParticipant2Avatar());
        copy.setLastMessagePreview(source.getLastMessagePreview());
        copy.setLastMessageAt(source.getLastMessageAt());
        copy.setCreatedAt(source.getCreatedAt());

        if (viewerId.equals(source.getParticipant1Id())) {
            // Viewer is participant 1 -> show participant 2
            if (source.getParticipant2Name() != null && !source.getParticipant2Name().isBlank()) {
                copy.setTitle(source.getParticipant2Name());
            } else {
                copy.setTitle(source.getTitle());
            }
            if (source.getParticipant2Avatar() != null && !source.getParticipant2Avatar().isBlank()) {
                copy.setAvatarUrl(source.getParticipant2Avatar());
            } else {
                copy.setAvatarUrl(source.getAvatarUrl());
            }
        } else if (viewerId.equals(source.getParticipant2Id())) {
            // Viewer is participant 2 -> show participant 1
            if (source.getParticipant1Name() != null && !source.getParticipant1Name().isBlank()) {
                copy.setTitle(source.getParticipant1Name());
            } else {
                copy.setTitle(source.getTitle());
            }
            if (source.getParticipant1Avatar() != null && !source.getParticipant1Avatar().isBlank()) {
                copy.setAvatarUrl(source.getParticipant1Avatar());
            } else {
                copy.setAvatarUrl(source.getAvatarUrl());
            }
        } else {
            copy.setTitle(source.getTitle());
            copy.setAvatarUrl(source.getAvatarUrl());
        }
        return copy;
    }
}
