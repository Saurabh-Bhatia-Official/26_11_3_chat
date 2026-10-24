package com.chatgen.backend.controller;

import com.chatgen.backend.model.Conversation;
import com.chatgen.backend.model.Message;
import com.chatgen.backend.repository.ConversationRepository;
import com.chatgen.backend.repository.MessageRepository;
import com.chatgen.backend.repository.UserRepository;
import com.chatgen.backend.service.CloudinaryService;
import com.chatgen.backend.service.SafetyAnalyzerService;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.messaging.handler.annotation.MessageMapping;
import org.springframework.messaging.handler.annotation.Payload;
import org.springframework.messaging.simp.SimpMessagingTemplate;
import org.springframework.web.bind.annotation.*;

import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.time.Instant;
import java.util.*;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.CopyOnWriteArrayList;

@RestController
@RequestMapping("/api/chat")
public class ChatController {

    private final ConversationRepository conversationRepository;
    private final MessageRepository messageRepository;
    private final UserRepository userRepository;
    private final SafetyAnalyzerService safetyAnalyzerService;
    private final SimpMessagingTemplate messagingTemplate;
    private final CloudinaryService cloudinaryService;

    private final Map<UUID, List<Message>> messageCache = new ConcurrentHashMap<>();
    private final Map<UUID, Long> messageCacheLastFetch = new ConcurrentHashMap<>();

    public ChatController(ConversationRepository conversationRepository,
                          MessageRepository messageRepository,
                          UserRepository userRepository,
                          SafetyAnalyzerService safetyAnalyzerService,
                          SimpMessagingTemplate messagingTemplate,
                          CloudinaryService cloudinaryService) {
        this.conversationRepository = conversationRepository;
        this.messageRepository = messageRepository;
        this.userRepository = userRepository;
        this.safetyAnalyzerService = safetyAnalyzerService;
        this.messagingTemplate = messagingTemplate;
        this.cloudinaryService = cloudinaryService;
    }

    private UUID parseOrGenerateUuid(String raw) {
        if (raw == null || raw.isBlank()) {
            return UUID.randomUUID();
        }
        try {
            return UUID.fromString(raw);
        } catch (IllegalArgumentException e) {
            return UUID.nameUUIDFromBytes(raw.getBytes(StandardCharsets.UTF_8));
        }
    }

    @GetMapping("/conversations")
    public ResponseEntity<List<Conversation>> getConversations(@RequestParam(required = false) String userId) {
        UUID uid = null;
        String rawUserId = (userId != null && !userId.isBlank() && !userId.equalsIgnoreCase("null") && !userId.equalsIgnoreCase("undefined")) ? userId.trim() : null;
        if (rawUserId != null) {
            try {
                uid = UUID.fromString(rawUserId);
            } catch (Exception ignored) {
                uid = UUID.nameUUIDFromBytes(rawUserId.getBytes(StandardCharsets.UTF_8));
            }
        }
        List<Conversation> list = new ArrayList<>();
        List<Conversation> all = conversationRepository.findAllByOrderByLastMessageAtDesc();
        if (uid != null || rawUserId != null) {
            String uidStr = uid != null ? uid.toString() : "";
            for (Conversation conv : all) {
                if (Boolean.TRUE.equals(conv.getIsGroup())) {
                    String pids = conv.getParticipantIds() != null ? conv.getParticipantIds() : "";
                    boolean inParticipants = (!uidStr.isEmpty() && pids.contains(uidStr)) || (rawUserId != null && pids.contains(rawUserId));
                    boolean isCreator = (conv.getCreatedBy() != null && (conv.getCreatedBy().equals(uid) || conv.getCreatedBy().toString().equalsIgnoreCase(rawUserId)))
                            || (conv.getParticipant1Id() != null && (conv.getParticipant1Id().equals(uid) || conv.getParticipant1Id().toString().equalsIgnoreCase(rawUserId)));
                    if (inParticipants || isCreator) {
                        list.add(conv);
                    }
                } else {
                    if ((conv.getParticipant1Id() != null && (conv.getParticipant1Id().equals(uid) || (rawUserId != null && conv.getParticipant1Id().toString().equalsIgnoreCase(rawUserId)))) ||
                        (conv.getParticipant2Id() != null && (conv.getParticipant2Id().equals(uid) || (rawUserId != null && conv.getParticipant2Id().toString().equalsIgnoreCase(rawUserId))))) {
                        list.add(conv);
                    }
                }
            }
            if (list.isEmpty()) {
                list = all;
            }
        } else {
            list = all;
        }

        List<Conversation> formatted = new ArrayList<>();
        for (Conversation conv : list) {
            ensureParticipantMetadata(conv);
            formatted.add(formatForViewer(conv, uid));
        }
        return ResponseEntity.ok()
                .header(HttpHeaders.CACHE_CONTROL, "no-cache, no-store, must-revalidate")
                .header(HttpHeaders.PRAGMA, "no-cache")
                .header(HttpHeaders.EXPIRES, "0")
                .body(formatted);
    }

    @PostMapping("/conversations")
    public ResponseEntity<Conversation> createConversation(@RequestBody Map<String, Object> payload) {
        UUID createdBy = payload.get("createdBy") != null ? parseOrGenerateUuid(payload.get("createdBy").toString()) : null;
        UUID p1 = payload.get("participant1Id") != null ? parseOrGenerateUuid(payload.get("participant1Id").toString()) : null;
        UUID p2 = payload.get("participant2Id") != null ? parseOrGenerateUuid(payload.get("participant2Id").toString()) : null;

        // If it's a 1-on-1 chat, check if conversation already exists between p1 and p2
        boolean isGroup = Boolean.parseBoolean(String.valueOf(payload.getOrDefault("isGroup", "false")));
        if (p1 != null && p2 != null && !isGroup) {
            Optional<Conversation> existing1 = conversationRepository.findFirstByParticipant1IdAndParticipant2Id(p1, p2);
            if (existing1.isPresent()) {
                Conversation c = existing1.get();
                ensureParticipantMetadata(c);
                return ResponseEntity.ok()
                        .header(HttpHeaders.CACHE_CONTROL, "no-cache, no-store, must-revalidate")
                        .body(formatForViewer(c, createdBy));
            }

            Optional<Conversation> existing2 = conversationRepository.findFirstByParticipant1IdAndParticipant2Id(p2, p1);
            if (existing2.isPresent()) {
                Conversation c = existing2.get();
                ensureParticipantMetadata(c);
                return ResponseEntity.ok()
                        .header(HttpHeaders.CACHE_CONTROL, "no-cache, no-store, must-revalidate")
                        .body(formatForViewer(c, createdBy));
            }
        }

        Conversation conversation = new Conversation();
        conversation.setTitle(payload.get("title") != null ? payload.get("title").toString() : "Chat");
        conversation.setIsGroup(isGroup);
        if (payload.get("avatarUrl") != null) conversation.setAvatarUrl(payload.get("avatarUrl").toString());
        conversation.setCreatedBy(createdBy);
        conversation.setParticipant1Id(p1);
        conversation.setParticipant2Id(p2);
        if (payload.get("participant1Name") != null) conversation.setParticipant1Name(payload.get("participant1Name").toString());
        if (payload.get("participant1Avatar") != null) conversation.setParticipant1Avatar(payload.get("participant1Avatar").toString());
        if (payload.get("participant2Name") != null) conversation.setParticipant2Name(payload.get("participant2Name").toString());
        if (payload.get("participant2Avatar") != null) conversation.setParticipant2Avatar(payload.get("participant2Avatar").toString());

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
        return ResponseEntity.ok()
                .header(HttpHeaders.CACHE_CONTROL, "no-cache, no-store, must-revalidate")
                .body(formatForViewer(saved, createdBy));
    }

    @DeleteMapping("/conversations/{id}")
    public ResponseEntity<?> deleteConversation(
            @PathVariable String id,
            @RequestParam(required = false) String userId
    ) {
        UUID convId = parseOrGenerateUuid(id);
        Optional<Conversation> convOpt = conversationRepository.findById(convId);
        if (convOpt.isPresent()) {
            Conversation conv = convOpt.get();
            List<Message> msgs = messageRepository.findByConversationIdOrderByCreatedAtAsc(convId);
            if (!msgs.isEmpty()) {
                // Synchronize file deletion with Cloudinary for all message attachments
                for (Message m : msgs) {
                    if (m.getMediaPublicId() != null && !m.getMediaPublicId().isBlank()) {
                        cloudinaryService.deleteFile(m.getMediaPublicId());
                    } else if (m.getMediaUrl() != null && !m.getMediaUrl().isBlank()) {
                        cloudinaryService.deleteFileByUrl(m.getMediaUrl());
                    }
                }
                messageRepository.deleteAll(msgs);
            }
            // If group/conversation avatar is hosted on Cloudinary, delete it
            if (conv.getAvatarUrl() != null && !conv.getAvatarUrl().isBlank()) {
                cloudinaryService.deleteFileByUrl(conv.getAvatarUrl());
            }
            messageCache.remove(convId);
            messageCacheLastFetch.remove(convId);
            conversationRepository.delete(conv);
        }
        return ResponseEntity.ok()
                .header(HttpHeaders.CACHE_CONTROL, "no-cache, no-store, must-revalidate")
                .body(Map.of("success", true, "message", "Conversation deleted successfully"));
    }

    @GetMapping("/conversations/{id}/messages")
    public ResponseEntity<List<Message>> getMessages(
            @PathVariable String id,
            @RequestParam(required = false) String userId
    ) {
        UUID convId = parseOrGenerateUuid(id);
        List<Message> messages;
        long now = System.currentTimeMillis();
        // Return instantly from in-memory cache if queried within 2.5 seconds
        if (messageCache.containsKey(convId) && (now - messageCacheLastFetch.getOrDefault(convId, 0L) < 2500)) {
            messages = messageCache.get(convId);
        } else {
            messages = messageRepository.findByConversationIdOrderByCreatedAtAsc(convId);
            messageCache.put(convId, new CopyOnWriteArrayList<>(messages));
            messageCacheLastFetch.put(convId, now);
        }

        if (userId != null && !userId.isBlank()) {
            final String uidStr = userId.trim();
            List<Message> filtered = new ArrayList<>();
            for (Message m : messages) {
                if (!m.getDeletedForUserIds().contains(uidStr)) {
                    filtered.add(m);
                }
            }
            return ResponseEntity.ok()
                    .header(HttpHeaders.CACHE_CONTROL, "no-cache, no-store, must-revalidate")
                    .body(filtered);
        }

        return ResponseEntity.ok()
                .header(HttpHeaders.CACHE_CONTROL, "no-cache, no-store, must-revalidate")
                .header(HttpHeaders.PRAGMA, "no-cache")
                .header(HttpHeaders.EXPIRES, "0")
                .body(messages);
    }

    @PutMapping("/messages/{id}")
    public ResponseEntity<?> editMessage(@PathVariable UUID id, @RequestBody Map<String, Object> payload) {
        return messageRepository.findById(id).map(message -> {
            // 1. Verify original sender
            String senderIdStr = payload.get("senderId") != null ? payload.get("senderId").toString() : "";
            if (!senderIdStr.isBlank()) {
                try {
                    UUID senderUid = UUID.fromString(senderIdStr);
                    if (!senderUid.equals(message.getSenderId())) {
                        return ResponseEntity.status(HttpStatus.FORBIDDEN)
                                .body(Map.of("error", "Only the original sender can edit this message."));
                    }
                } catch (Exception ignored) {}
            }

            // 2. Validate 5-minute time limit on the backend
            if (message.getCreatedAt() != null) {
                long minutesElapsed = Duration.between(message.getCreatedAt(), Instant.now()).toMinutes();
                if (minutesElapsed >= 5) {
                    return ResponseEntity.status(HttpStatus.BAD_REQUEST)
                            .body(Map.of("error", "Messages can only be edited within 5 minutes of sending."));
                }
            }

            // 3. Update content and mark edited
            String newContent = payload.getOrDefault("content", "").toString();
            if (newContent.isBlank()) {
                return ResponseEntity.badRequest().body(Map.of("error", "Message content cannot be empty."));
            }

            message.setContent(newContent);
            message.setIsEdited(true);
            message.setEditedAt(Instant.now());
            Message saved = messageRepository.save(message);

            // Update in-memory cache
            if (messageCache.containsKey(saved.getConversationId())) {
                List<Message> cached = messageCache.get(saved.getConversationId());
                for (int i = 0; i < cached.size(); i++) {
                    if (cached.get(i).getId().equals(saved.getId())) {
                        cached.set(i, saved);
                        break;
                    }
                }
            }

            // Broadcast real-time edit event to conversation
            Map<String, Object> event = new HashMap<>();
            event.put("action", "EDIT_MESSAGE");
            event.put("message", saved);
            try {
                messagingTemplate.convertAndSend("/topic/conversation." + saved.getConversationId(), event);
            } catch (Exception ignored) {}

            return ResponseEntity.ok(saved);
        }).orElse(ResponseEntity.notFound().build());
    }

    @DeleteMapping("/messages/{id}/me")
    public ResponseEntity<?> deleteMessageForMe(@PathVariable UUID id, @RequestParam String userId) {
        return messageRepository.findById(id).map(message -> {
            String current = message.getDeletedForUserIds();
            if (!current.contains(userId)) {
                message.setDeletedForUserIds(current.isEmpty() ? userId : current + "," + userId);
                messageRepository.save(message);
            }
            return ResponseEntity.ok(Map.of("success", true, "messageId", id, "action", "DELETE_FOR_ME"));
        }).orElse(ResponseEntity.notFound().build());
    }

    @DeleteMapping("/messages/{id}/everyone")
    public ResponseEntity<?> deleteMessageForEveryone(@PathVariable UUID id, @RequestParam String userId) {
        return messageRepository.findById(id).map(message -> {
            // Check permissions: sender or group admin
            boolean isSender = userId.equalsIgnoreCase(message.getSenderId().toString());
            boolean isAdmin = false;
            Optional<Conversation> convOpt = conversationRepository.findById(message.getConversationId());
            if (convOpt.isPresent()) {
                Conversation conv = convOpt.get();
                if (Boolean.TRUE.equals(conv.getIsGroup()) && conv.getGroupAdminIds().contains(userId)) {
                    isAdmin = true;
                }
            }

            if (!isSender && !isAdmin) {
                return ResponseEntity.status(HttpStatus.FORBIDDEN)
                        .body(Map.of("error", "You do not have permission to delete this message for everyone."));
            }

            // Synchronize deletion with Cloudinary if media was attached
            if (message.getMediaPublicId() != null && !message.getMediaPublicId().isBlank()) {
                cloudinaryService.deleteFile(message.getMediaPublicId());
            } else if (message.getMediaUrl() != null && !message.getMediaUrl().isBlank()) {
                cloudinaryService.deleteFileByUrl(message.getMediaUrl());
            }

            message.setIsDeleted(true);
            message.setContent("This message was deleted");
            message.setMediaUrl(null);
            message.setMediaPublicId(null);
            message.setMediaBytes(null);
            Message saved = messageRepository.save(message);

            // Update cache
            if (messageCache.containsKey(saved.getConversationId())) {
                List<Message> cached = messageCache.get(saved.getConversationId());
                for (int i = 0; i < cached.size(); i++) {
                    if (cached.get(i).getId().equals(saved.getId())) {
                        cached.set(i, saved);
                        break;
                    }
                }
            }

            // Real-time broadcast
            Map<String, Object> event = new HashMap<>();
            event.put("action", "DELETE_FOR_EVERYONE");
            event.put("messageId", saved.getId());
            event.put("message", saved);
            try {
                messagingTemplate.convertAndSend("/topic/conversation." + saved.getConversationId(), event);
            } catch (Exception ignored) {}

            return ResponseEntity.ok(saved);
        }).orElse(ResponseEntity.notFound().build());
    }

    @PostMapping("/groups")
    public ResponseEntity<?> createGroup(@RequestBody Map<String, Object> payload) {
        String title = payload.get("title") != null ? payload.get("title").toString().trim() : "New Group";
        if (title.isEmpty()) title = "New Group";
        String description = payload.get("description") != null ? payload.get("description").toString().trim() : "";
        String avatarUrl = payload.get("avatarUrl") != null ? payload.get("avatarUrl").toString().trim() : "";
        String adminIdStr = payload.get("adminId") != null ? payload.get("adminId").toString().trim()
                : (payload.get("requesterId") != null ? payload.get("requesterId").toString().trim() : "");
        UUID adminId = parseOrGenerateUuid(adminIdStr);

        List<String> memberList = new ArrayList<>();
        if (!adminIdStr.isBlank() && !memberList.contains(adminIdStr)) {
            memberList.add(adminIdStr);
        }
        if (!memberList.contains(adminId.toString())) {
            memberList.add(adminId.toString());
        }
        if (payload.get("memberIds") instanceof List<?>) {
            for (Object m : (List<?>) payload.get("memberIds")) {
                if (m != null && !m.toString().isBlank()) {
                    String mStr = m.toString().trim();
                    if (!memberList.contains(mStr)) {
                        memberList.add(mStr);
                    }
                }
            }
        }

        Conversation group = new Conversation();
        group.setTitle(title);
        group.setDescription(description);
        group.setAvatarUrl(avatarUrl.isBlank() ? null : avatarUrl);
        group.setIsGroup(true);
        group.setCreatedBy(adminId);
        group.setParticipant1Id(adminId);
        group.setGroupAdminIds(adminId.toString() + (adminIdStr.isBlank() || adminIdStr.equals(adminId.toString()) ? "" : "," + adminIdStr));
        group.setParticipantIds(String.join(",", memberList));
        group.setCreatedAt(Instant.now());
        group.setLastMessageAt(Instant.now());

        String adminName = "Admin";
        var adminUser = userRepository.findById(adminId);
        if (adminUser.isPresent()) {
            adminName = adminUser.get().getDisplayName();
            group.setParticipant1Name(adminName);
            group.setParticipant1Avatar(adminUser.get().getAvatarUrl());
        } else {
            group.setParticipant1Name(adminName);
        }

        Conversation saved = conversationRepository.save(group);

        // Create initial system message safely
        try {
            Message sysMsg = new Message();
            sysMsg.setConversationId(saved.getId());
            sysMsg.setSenderId(adminId);
            sysMsg.setSenderName("System");
            sysMsg.setContent(adminName + " created the group \"" + title + "\"");
            sysMsg.setType("SYSTEM");
            sysMsg.setCreatedAt(Instant.now());
            Message savedMsg = processAndSaveMessage(sysMsg);

            saved.setLastMessagePreview(savedMsg.getContent());
            conversationRepository.save(saved);

            try {
                messagingTemplate.convertAndSend("/topic/conversation." + saved.getId(), savedMsg);
            } catch (Exception ignored) {}
        } catch (Exception e) {
            saved.setLastMessagePreview(adminName + " created the group \"" + title + "\"");
            conversationRepository.save(saved);
        }

        return ResponseEntity.ok()
                .header(HttpHeaders.CACHE_CONTROL, "no-cache, no-store, must-revalidate")
                .body(saved);
    }

    @GetMapping("/groups/{id}/members")
    public ResponseEntity<?> getGroupMembers(@PathVariable String id) {
        UUID convId = parseOrGenerateUuid(id);
        return conversationRepository.findById(convId).map(conv -> {
            if (!Boolean.TRUE.equals(conv.getIsGroup())) {
                return ResponseEntity.badRequest().body(Map.of("error", "Conversation is not a group."));
            }
            List<Map<String, Object>> members = new ArrayList<>();
            String[] pids = (conv.getParticipantIds() != null ? conv.getParticipantIds() : "").split(",");
            String adminIds = conv.getGroupAdminIds() != null ? conv.getGroupAdminIds() : "";

            for (String pidStr : pids) {
                if (pidStr.isBlank()) continue;
                try {
                    UUID uid = parseOrGenerateUuid(pidStr.trim());
                    userRepository.findById(uid).ifPresent(u -> {
                        Map<String, Object> m = new HashMap<>();
                        m.put("id", u.getId());
                        m.put("username", u.getUsername());
                        m.put("displayName", u.getDisplayName());
                        m.put("avatarUrl", u.getAvatarUrl());
                        m.put("statusMessage", u.getStatusMessage());
                        m.put("isAdmin", adminIds.contains(u.getId().toString()) || u.getId().equals(conv.getCreatedBy()));
                        members.add(m);
                    });
                } catch (Exception ignored) {}
            }
            if (members.isEmpty() && conv.getCreatedBy() != null) {
                Map<String, Object> adminFallback = new HashMap<>();
                adminFallback.put("id", conv.getCreatedBy());
                adminFallback.put("username", "admin");
                adminFallback.put("displayName", conv.getParticipant1Name() != null ? conv.getParticipant1Name() : "Admin");
                adminFallback.put("avatarUrl", conv.getParticipant1Avatar());
                adminFallback.put("statusMessage", "Group Admin");
                adminFallback.put("isAdmin", true);
                members.add(adminFallback);
            }
            return ResponseEntity.ok(members);
        }).orElse(ResponseEntity.notFound().build());
    }

    @PostMapping("/groups/{id}/members")
    public ResponseEntity<?> addGroupMember(@PathVariable String id, @RequestBody Map<String, Object> payload) {
        UUID convId = parseOrGenerateUuid(id);
        return conversationRepository.findById(convId).map(conv -> {
            String newUserId = payload.get("userId") != null ? payload.get("userId").toString().trim() : "";
            String requesterId = payload.get("requesterId") != null ? payload.get("requesterId").toString().trim()
                    : (payload.get("adminId") != null ? payload.get("adminId").toString().trim() : "");

            String adminIds = conv.getGroupAdminIds() != null ? conv.getGroupAdminIds() : "";
            boolean isAdmin = adminIds.contains(requesterId) || (conv.getCreatedBy() != null && conv.getCreatedBy().toString().equals(requesterId));

            if (!isAdmin && !requesterId.isBlank()) {
                return ResponseEntity.status(HttpStatus.FORBIDDEN).body(Map.of("error", "Only group admins can add members."));
            }

            String current = conv.getParticipantIds() != null ? conv.getParticipantIds() : "";
            if (!newUserId.isBlank() && !current.contains(newUserId)) {
                conv.setParticipantIds(current.isEmpty() ? newUserId : current + "," + newUserId);
                conversationRepository.save(conv);

                String addedName = "New Member";
                try {
                    var addedUser = userRepository.findById(parseOrGenerateUuid(newUserId));
                    if (addedUser.isPresent()) addedName = addedUser.get().getDisplayName();
                } catch (Exception ignored) {}

                String adminName = "Admin";
                try {
                    var adminUser = userRepository.findById(parseOrGenerateUuid(requesterId));
                    if (adminUser.isPresent()) adminName = adminUser.get().getDisplayName();
                } catch (Exception ignored) {}

                Message sysMsg = new Message();
                sysMsg.setConversationId(conv.getId());
                sysMsg.setSenderId(parseOrGenerateUuid(requesterId));
                sysMsg.setSenderName("System");
                sysMsg.setContent(adminName + " added " + addedName + " to the group");
                sysMsg.setType("SYSTEM");
                try {
                    Message savedMsg = processAndSaveMessage(sysMsg);
                    messagingTemplate.convertAndSend("/topic/conversation." + conv.getId(), savedMsg);
                } catch (Exception ignored) {}
            }
            return ResponseEntity.ok(conv);
        }).orElse(ResponseEntity.notFound().build());
    }

    @DeleteMapping("/groups/{id}/members/{userId}")
    public ResponseEntity<?> removeGroupMember(
            @PathVariable String id,
            @PathVariable String userId,
            @RequestParam(required = false) String requesterId,
            @RequestParam(required = false) String adminId
    ) {
        UUID convId = parseOrGenerateUuid(id);
        String effectiveRequesterId = (requesterId != null && !requesterId.isBlank()) ? requesterId
                : (adminId != null ? adminId : "");

        return conversationRepository.findById(convId).map(conv -> {
            boolean isLeavingSelf = userId.equalsIgnoreCase(effectiveRequesterId);
            String adminIds = conv.getGroupAdminIds() != null ? conv.getGroupAdminIds() : "";
            boolean isAdmin = adminIds.contains(effectiveRequesterId) || (conv.getCreatedBy() != null && conv.getCreatedBy().toString().equals(effectiveRequesterId));

            if (!isLeavingSelf && !isAdmin && !effectiveRequesterId.isBlank()) {
                return ResponseEntity.status(HttpStatus.FORBIDDEN).body(Map.of("error", "Only admins can remove other members."));
            }

            List<String> remaining = new ArrayList<>();
            String current = conv.getParticipantIds() != null ? conv.getParticipantIds() : "";
            for (String pid : current.split(",")) {
                if (!pid.isBlank() && !pid.trim().equalsIgnoreCase(userId)) {
                    remaining.add(pid.trim());
                }
            }
            conv.setParticipantIds(String.join(",", remaining));
            conversationRepository.save(conv);

            String userName = "Member";
            try {
                var u = userRepository.findById(parseOrGenerateUuid(userId));
                if (u.isPresent()) userName = u.get().getDisplayName();
            } catch (Exception ignored) {}

            String content = isLeavingSelf ? (userName + " left the group") : ("Admin removed " + userName + " from the group");
            Message sysMsg = new Message();
            sysMsg.setConversationId(conv.getId());
            sysMsg.setSenderId(parseOrGenerateUuid(effectiveRequesterId));
            sysMsg.setSenderName("System");
            sysMsg.setContent(content);
            sysMsg.setType("SYSTEM");
            try {
                Message savedMsg = processAndSaveMessage(sysMsg);
                messagingTemplate.convertAndSend("/topic/conversation." + conv.getId(), savedMsg);
            } catch (Exception ignored) {}

            return ResponseEntity.ok(Map.of("success", true, "userId", userId));
        }).orElse(ResponseEntity.notFound().build());
    }

    @PutMapping("/groups/{id}")
    public ResponseEntity<?> updateGroup(@PathVariable String id, @RequestBody Map<String, Object> payload) {
        UUID convId = parseOrGenerateUuid(id);
        return conversationRepository.findById(convId).map(conv -> {
            String requesterId = payload.get("requesterId") != null ? payload.get("requesterId").toString()
                    : (payload.get("adminId") != null ? payload.get("adminId").toString() : "");
            String adminIds = conv.getGroupAdminIds() != null ? conv.getGroupAdminIds() : "";
            boolean isAdmin = adminIds.contains(requesterId) || (conv.getCreatedBy() != null && conv.getCreatedBy().toString().equals(requesterId));

            if (!isAdmin && !requesterId.isBlank()) {
                return ResponseEntity.status(HttpStatus.FORBIDDEN).body(Map.of("error", "Only group admins can update group info."));
            }
            if (payload.containsKey("title") && payload.get("title") != null) {
                String title = payload.get("title").toString().trim();
                if (!title.isEmpty()) conv.setTitle(title);
            }
            if (payload.containsKey("description")) {
                conv.setDescription(payload.get("description") != null ? payload.get("description").toString().trim() : "");
            }
            if (payload.containsKey("avatarUrl")) {
                conv.setAvatarUrl(payload.get("avatarUrl") != null ? payload.get("avatarUrl").toString().trim() : null);
            }
            return ResponseEntity.ok(conversationRepository.save(conv));
        }).orElse(ResponseEntity.notFound().build());
    }

    @PostMapping("/conversations/{id}/messages")
    public ResponseEntity<Message> sendMessageRest(@PathVariable String id, @RequestBody Map<String, Object> payload) {
        UUID convId = parseOrGenerateUuid(id);
        Message message = new Message();
        message.setConversationId(convId);
        if (payload.get("senderId") != null) {
            message.setSenderId(parseOrGenerateUuid(payload.get("senderId").toString()));
        }
        if (payload.get("senderName") != null) {
            message.setSenderName(payload.get("senderName").toString());
        }
        if (payload.get("senderAvatarUrl") != null) {
            message.setSenderAvatarUrl(payload.get("senderAvatarUrl").toString());
        }
        if (payload.get("content") != null) {
            message.setContent(payload.get("content").toString());
        }
        if (payload.get("type") != null) {
            message.setType(payload.get("type").toString());
        }
        if (payload.get("mediaUrl") != null) {
            String mUrl = payload.get("mediaUrl").toString();
            message.setMediaUrl(mUrl);
            if (message.getMediaPublicId() == null) {
                message.setMediaPublicId(cloudinaryService.extractPublicIdFromUrl(mUrl));
            }
        }
        if (payload.get("mediaPublicId") != null) {
            message.setMediaPublicId(payload.get("mediaPublicId").toString());
        }
        if (payload.get("mediaBytes") != null) {
            try {
                message.setMediaBytes(Long.parseLong(payload.get("mediaBytes").toString()));
            } catch (Exception ignored) {}
        }

        Message saved = processAndSaveMessage(message);

        // Update in-memory cache instantly
        messageCache.computeIfAbsent(convId, k -> new CopyOnWriteArrayList<>()).add(saved);
        messageCacheLastFetch.put(convId, System.currentTimeMillis());

        try {
            messagingTemplate.convertAndSend("/topic/conversation." + convId, saved);
        } catch (Exception ignored) {}

        return ResponseEntity.ok()
                .header(HttpHeaders.CACHE_CONTROL, "no-cache, no-store, must-revalidate")
                .body(saved);
    }

    @MessageMapping("/chat.sendMessage")
    public void sendMessageWebSocket(@Payload Message message) {
        Message saved = processAndSaveMessage(message);
        if (saved.getConversationId() != null) {
            messageCache.computeIfAbsent(saved.getConversationId(), k -> new CopyOnWriteArrayList<>()).add(saved);
            messageCacheLastFetch.put(saved.getConversationId(), System.currentTimeMillis());
            messagingTemplate.convertAndSend("/topic/conversation." + saved.getConversationId(), saved);
        }
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

        // Ensure mediaPublicId is extracted and stored if mediaUrl is a Cloudinary asset
        if (message.getMediaPublicId() == null && message.getMediaUrl() != null) {
            message.setMediaPublicId(cloudinaryService.extractPublicIdFromUrl(message.getMediaUrl()));
        }

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
