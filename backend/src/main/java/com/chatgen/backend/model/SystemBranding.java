package com.chatgen.backend.model;

import jakarta.persistence.*;
import java.time.Instant;

@Entity
@Table(name = "system_branding")
public class SystemBranding {

    @Id
    @Column(length = 50)
    private String id = "default";

    @Column(length = 150)
    private String softwareName = "Whisper";

    @Column(columnDefinition = "TEXT")
    private String customLogoUrl;

    @Column(length = 50)
    private String themePreference = "obsidianCyber";

    @Column(length = 50)
    private String appIconPreference = "whisper";

    private Instant updatedAt = Instant.now();

    public SystemBranding() {}

    public String getId() { return id; }
    public void setId(String id) { this.id = id; }

    public String getSoftwareName() { return softwareName; }
    public void setSoftwareName(String softwareName) { this.softwareName = softwareName; }

    public String getCustomLogoUrl() { return customLogoUrl; }
    public void setCustomLogoUrl(String customLogoUrl) { this.customLogoUrl = customLogoUrl; }

    public String getThemePreference() { return themePreference; }
    public void setThemePreference(String themePreference) { this.themePreference = themePreference; }

    public String getAppIconPreference() { return appIconPreference; }
    public void setAppIconPreference(String appIconPreference) { this.appIconPreference = appIconPreference; }

    public Instant getUpdatedAt() { return updatedAt; }
    public void setUpdatedAt(Instant updatedAt) { this.updatedAt = updatedAt; }
}
