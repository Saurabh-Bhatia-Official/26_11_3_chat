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
    private String participant1Name;
    @Column(columnDefinition = "TEXT")
    private String participant1Avatar;

    private UUID participant2Id;
    private String participant2Name;
    @Column(columnDefinition = "TEXT")
    private String participant2Avatar;

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

    public String getParticipant1Name() { return participant1Name; }
    public void setParticipant1Name(String participant1Name) { this.participant1Name = participant1Name; }

    public String getParticipant1Avatar() { return participant1Avatar; }
    public void setParticipant1Avatar(String participant1Avatar) { this.participant1Avatar = participant1Avatar; }

    public UUID getParticipant2Id() { return participant2Id; }
    public void setParticipant2Id(UUID participant2Id) { this.participant2Id = participant2Id; }

    public String getParticipant2Name() { return participant2Name; }
    public void setParticipant2Name(String participant2Name) { this.participant2Name = participant2Name; }

    public String getParticipant2Avatar() { return participant2Avatar; }
    public void setParticipant2Avatar(String participant2Avatar) { this.participant2Avatar = participant2Avatar; }

    @Column(columnDefinition = "TEXT")
    private String description;

    @Column(columnDefinition = "TEXT")
    private String groupAdminIds;

    @Column(columnDefinition = "TEXT")
    private String participantIds;

    public String getDescription() { return description; }
    public void setDescription(String description) { this.description = description; }

    public String getGroupAdminIds() { return groupAdminIds != null ? groupAdminIds : ""; }
    public void setGroupAdminIds(String groupAdminIds) { this.groupAdminIds = groupAdminIds; }

    public String getParticipantIds() { return participantIds != null ? participantIds : ""; }
    public void setParticipantIds(String participantIds) { this.participantIds = participantIds; }

    public String getLastMessagePreview() { return lastMessagePreview; }
    public void setLastMessagePreview(String lastMessagePreview) { this.lastMessagePreview = lastMessagePreview; }

    public Instant getLastMessageAt() { return lastMessageAt; }
    public void setLastMessageAt(Instant lastMessageAt) { this.lastMessageAt = lastMessageAt; }

    public Instant getCreatedAt() { return createdAt; }
    public void setCreatedAt(Instant createdAt) { this.createdAt = createdAt; }
}
