package com.chatgen.backend.model;

import jakarta.persistence.*;
import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "safety_events")
public class SafetyEvent {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @Column(nullable = false)
    private UUID userId;

    @Column(nullable = false, length = 50)
    private String eventType; // SUSPICIOUS_LOGIN, MALICIOUS_LINK, SESSION_TERMINATED, PERMISSION_ALERT

    @Column(length = 20)
    private String severity = "LOW"; // LOW, MEDIUM, HIGH, CRITICAL

    @Column(columnDefinition = "TEXT", nullable = false)
    private String description;

    private String ipAddress;

    @Column(columnDefinition = "TEXT")
    private String metadataJson;

    private Boolean isAcknowledged = false;

    private Instant createdAt = Instant.now();

    public SafetyEvent() {}

    public UUID getId() { return id; }
    public void setId(UUID id) { this.id = id; }

    public UUID getUserId() { return userId; }
    public void setUserId(UUID userId) { this.userId = userId; }

    public String getEventType() { return eventType; }
    public void setEventType(String eventType) { this.eventType = eventType; }

    public String getSeverity() { return severity; }
    public void setSeverity(String severity) { this.severity = severity; }

    public String getDescription() { return description; }
    public void setDescription(String description) { this.description = description; }

    public String getIpAddress() { return ipAddress; }
    public void setIpAddress(String ipAddress) { this.ipAddress = ipAddress; }

    public String getMetadataJson() { return metadataJson; }
    public void setMetadataJson(String metadataJson) { this.metadataJson = metadataJson; }

    public Boolean getIsAcknowledged() { return isAcknowledged; }
    public void setIsAcknowledged(Boolean acknowledged) { isAcknowledged = acknowledged; }

    public Instant getCreatedAt() { return createdAt; }
    public void setCreatedAt(Instant createdAt) { this.createdAt = createdAt; }
}
