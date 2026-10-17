package com.chatgen.backend.model;

import jakarta.persistence.*;
import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "conversations")
public class Conversation {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    private String title;

    private Boolean isGroup = false;

    @Column(columnDefinition = "TEXT")
    private String avatarUrl;

    private UUID createdBy;

    private UUID participant1Id;

    private UUID participant2Id;

    @Column(columnDefinition = "TEXT")
    private String lastMessagePreview;

    private Instant lastMessageAt = Instant.now();

    private Instant createdAt = Instant.now();

    public Conversation() {}

    public UUID getId() { return id; }
    public void setId(UUID id) { this.id = id; }

    public String getTitle() { return title; }
    public void setTitle(String title) { this.title = title; }

    public Boolean getIsGroup() { return isGroup; }
    public void setIsGroup(Boolean isGroup) { this.isGroup = isGroup; }

    public String getAvatarUrl() { return avatarUrl; }
    public void setAvatarUrl(String avatarUrl) { this.avatarUrl = avatarUrl; }

    public UUID getCreatedBy() { return createdBy; }
    public void setCreatedBy(UUID createdBy) { this.createdBy = createdBy; }

    public UUID getParticipant1Id() { return participant1Id; }
    public void setParticipant1Id(UUID participant1Id) { this.participant1Id = participant1Id; }

    public UUID getParticipant2Id() { return participant2Id; }
    public void setParticipant2Id(UUID participant2Id) { this.participant2Id = participant2Id; }

    public String getLastMessagePreview() { return lastMessagePreview; }
    public void setLastMessagePreview(String lastMessagePreview) { this.lastMessagePreview = lastMessagePreview; }

    public Instant getLastMessageAt() { return lastMessageAt; }
    public void setLastMessageAt(Instant lastMessageAt) { this.lastMessageAt = lastMessageAt; }

    public Instant getCreatedAt() { return createdAt; }
    public void setCreatedAt(Instant createdAt) { this.createdAt = createdAt; }
}
