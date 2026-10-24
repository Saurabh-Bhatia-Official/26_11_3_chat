package com.chatgen.backend.model;

import jakarta.persistence.*;
import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "messages")
public class Message {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @Column(nullable = false)
    private UUID conversationId;

    @Column(nullable = false)
    private UUID senderId;

    private String senderName;
    private String senderAvatarUrl;

    @Column(columnDefinition = "TEXT", nullable = false)
    private String content;

    @Column(length = 30)
    private String type = "TEXT"; // TEXT, IMAGE, AUDIO, VIDEO, FILE, GAME_INVITE, SYSTEM

    @Column(columnDefinition = "TEXT")
    private String mediaUrl;

    private String mediaPublicId;

    private Long mediaBytes;

    private UUID replyToId;

    private Boolean isEdited = false;

    private Boolean isDeleted = false;

    private Boolean safetyFlagged = false;

    private String deliveryStatus = "DELIVERED"; // SENT, DELIVERED, READ

    private Instant createdAt = Instant.now();

    public Message() {}

    public UUID getId() { return id; }
    public void setId(UUID id) { this.id = id; }

    public UUID getConversationId() { return conversationId; }
    public void setConversationId(UUID conversationId) { this.conversationId = conversationId; }

    public UUID getSenderId() { return senderId; }
    public void setSenderId(UUID senderId) { this.senderId = senderId; }

    public String getSenderName() { return senderName; }
    public void setSenderName(String senderName) { this.senderName = senderName; }

    public String getSenderAvatarUrl() { return senderAvatarUrl; }
    public void setSenderAvatarUrl(String senderAvatarUrl) { this.senderAvatarUrl = senderAvatarUrl; }

    public String getContent() { return content; }
    public void setContent(String content) { this.content = content; }

    public String getType() { return type; }
    public void setType(String type) { this.type = type; }

    public String getMediaUrl() { return mediaUrl; }
    public void setMediaUrl(String mediaUrl) { this.mediaUrl = mediaUrl; }

    public String getMediaPublicId() { return mediaPublicId; }
    public void setMediaPublicId(String mediaPublicId) { this.mediaPublicId = mediaPublicId; }

    public Long getMediaBytes() { return mediaBytes; }
    public void setMediaBytes(Long mediaBytes) { this.mediaBytes = mediaBytes; }

    public UUID getReplyToId() { return replyToId; }
    public void setReplyToId(UUID replyToId) { this.replyToId = replyToId; }

    public Boolean getIsEdited() { return isEdited; }
    public void setIsEdited(Boolean edited) { isEdited = edited; }

    public Boolean getIsDeleted() { return isDeleted; }
    public void setIsDeleted(Boolean deleted) { isDeleted = deleted; }

    @Column(columnDefinition = "TEXT")
    private String deletedForUserIds = "";

    private Instant editedAt;

    public String getDeletedForUserIds() { return deletedForUserIds != null ? deletedForUserIds : ""; }
    public void setDeletedForUserIds(String deletedForUserIds) { this.deletedForUserIds = deletedForUserIds; }

    public Instant getEditedAt() { return editedAt; }
    public void setEditedAt(Instant editedAt) { this.editedAt = editedAt; }

    public Boolean getSafetyFlagged() { return safetyFlagged; }
    public void setSafetyFlagged(Boolean safetyFlagged) { this.safetyFlagged = safetyFlagged; }

    public String getDeliveryStatus() { return deliveryStatus; }
    public void setDeliveryStatus(String deliveryStatus) { this.deliveryStatus = deliveryStatus; }

    public Instant getCreatedAt() { return createdAt; }
    public void setCreatedAt(Instant createdAt) { this.createdAt = createdAt; }
}
