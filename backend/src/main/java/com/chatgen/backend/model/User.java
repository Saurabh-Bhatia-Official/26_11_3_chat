package com.chatgen.backend.model;

import com.fasterxml.jackson.annotation.JsonIgnore;
import jakarta.persistence.*;
import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "users")
public class User {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @Column(unique = true, nullable = false, length = 50)
    private String username;

    @Column(nullable = false, length = 100)
    private String displayName;

    @Column(unique = true, length = 255)
    private String email;

    @JsonIgnore
    private String password;

    @Column(length = 30)
    private String phone;

    @Column(columnDefinition = "TEXT")
    private String avatarUrl;

    @Column(columnDefinition = "TEXT")
    private String bio;

    @Column(length = 150)
    private String statusMessage = "Available";

    private Integer safetyScore = 100;

    private String themePreference = "dark_cyber";

    private String appIconPreference = "cyber_pulse";

    private Boolean isVerified = false;

    private Instant lastSeen = Instant.now();

    private Instant createdAt = Instant.now();

    public User() {}

    public UUID getId() { return id; }
    public void setId(UUID id) { this.id = id; }

    public String getUsername() { return username; }
    public void setUsername(String username) { this.username = username; }

    public String getDisplayName() { return displayName; }
    public void setDisplayName(String displayName) { this.displayName = displayName; }

    public String getEmail() { return email; }
    public void setEmail(String email) { this.email = email; }

    public String getPassword() { return password; }
    public void setPassword(String password) { this.password = password; }

    public String getPhone() { return phone; }
    public void setPhone(String phone) { this.phone = phone; }

    public String getAvatarUrl() { return avatarUrl; }
    public void setAvatarUrl(String avatarUrl) { this.avatarUrl = avatarUrl; }

    public String getBio() { return bio; }
    public void setBio(String bio) { this.bio = bio; }

    public String getStatusMessage() { return statusMessage; }
    public void setStatusMessage(String statusMessage) { this.statusMessage = statusMessage; }

    public Integer getSafetyScore() { return safetyScore; }
    public void setSafetyScore(Integer safetyScore) { this.safetyScore = safetyScore; }

    public String getThemePreference() { return themePreference; }
    public void setThemePreference(String themePreference) { this.themePreference = themePreference; }

    public String getAppIconPreference() { return appIconPreference; }
    public void setAppIconPreference(String appIconPreference) { this.appIconPreference = appIconPreference; }

    @Column(length = 150)
    private String softwareName = "Whisper";

    @Column(columnDefinition = "TEXT")
    private String customLogoUrl;

    public String getSoftwareName() { return softwareName; }
    public void setSoftwareName(String softwareName) { this.softwareName = softwareName; }

    public String getCustomLogoUrl() { return customLogoUrl; }
    public void setCustomLogoUrl(String customLogoUrl) { this.customLogoUrl = customLogoUrl; }

    public Boolean getIsVerified() { return isVerified; }
    public void setIsVerified(Boolean verified) { isVerified = verified; }

    private Boolean isPrivate = false;

    @com.fasterxml.jackson.annotation.JsonProperty("isPrivate")
    public Boolean getIsPrivate() { return isPrivate != null ? isPrivate : false; }

    @com.fasterxml.jackson.annotation.JsonProperty("isPrivate")
    public void setIsPrivate(Boolean isPrivate) { this.isPrivate = isPrivate; }

    public Instant getLastSeen() { return lastSeen; }
    public void setLastSeen(Instant lastSeen) { this.lastSeen = lastSeen; }

    public Instant getCreatedAt() { return createdAt; }
    public void setCreatedAt(Instant createdAt) { this.createdAt = createdAt; }
}
