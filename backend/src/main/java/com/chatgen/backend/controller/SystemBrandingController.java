package com.chatgen.backend.controller;

import com.chatgen.backend.model.SystemBranding;
import com.chatgen.backend.repository.SystemBrandingRepository;
import com.chatgen.backend.service.CloudinaryService;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.time.Instant;
import java.util.Map;

@RestController
@RequestMapping("/api/system/branding")
public class SystemBrandingController {

    private final SystemBrandingRepository repository;
    private final CloudinaryService cloudinaryService;

    public SystemBrandingController(SystemBrandingRepository repository, CloudinaryService cloudinaryService) {
        this.repository = repository;
        this.cloudinaryService = cloudinaryService;
    }

    @GetMapping
    public ResponseEntity<SystemBranding> getBranding() {
        SystemBranding branding = repository.findById("default").orElseGet(() -> {
            SystemBranding def = new SystemBranding();
            return repository.save(def);
        });
        return ResponseEntity.ok(branding);
    }

    @PostMapping
    public ResponseEntity<SystemBranding> updateBranding(@RequestBody Map<String, Object> updates) {
        SystemBranding branding = repository.findById("default").orElseGet(SystemBranding::new);

        if (updates.containsKey("softwareName") && updates.get("softwareName") != null) {
            String name = (String) updates.get("softwareName");
            if (!name.trim().isEmpty()) {
                branding.setSoftwareName(name.trim());
            }
        }
        if (updates.containsKey("customLogoUrl")) {
            String newLogo = (String) updates.get("customLogoUrl");
            String oldLogo = branding.getCustomLogoUrl();
            if (oldLogo != null && !oldLogo.equals(newLogo) && oldLogo.contains("cloudinary.com")) {
                cloudinaryService.deleteFileByUrl(oldLogo);
            }
            branding.setCustomLogoUrl(newLogo);
        }
        if (updates.containsKey("themePreference") && updates.get("themePreference") != null) {
            branding.setThemePreference((String) updates.get("themePreference"));
        }
        if (updates.containsKey("appIconPreference") && updates.get("appIconPreference") != null) {
            branding.setAppIconPreference((String) updates.get("appIconPreference"));
        }
        branding.setUpdatedAt(Instant.now());
        return ResponseEntity.ok(repository.save(branding));
    }
}
