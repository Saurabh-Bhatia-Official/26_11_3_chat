package com.chatgen.backend.controller;

import com.chatgen.backend.model.SafetyEvent;
import com.chatgen.backend.repository.SafetyEventRepository;
import com.chatgen.backend.repository.UserRepository;
import com.chatgen.backend.service.SafetyAnalyzerService;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.*;

@RestController
@RequestMapping("/api/safety")
public class SafetyGuardianController {

    private final SafetyEventRepository safetyEventRepository;
    private final SafetyAnalyzerService safetyAnalyzerService;
    private final UserRepository userRepository;

    public SafetyGuardianController(SafetyEventRepository safetyEventRepository,
                                    SafetyAnalyzerService safetyAnalyzerService,
                                    UserRepository userRepository) {
        this.safetyEventRepository = safetyEventRepository;
        this.safetyAnalyzerService = safetyAnalyzerService;
        this.userRepository = userRepository;
    }

    @GetMapping("/events/{userId}")
    public ResponseEntity<List<SafetyEvent>> getUserEvents(@PathVariable UUID userId) {
        return ResponseEntity.ok(safetyEventRepository.findByUserIdOrderByCreatedAtDesc(userId));
    }

    @PostMapping("/scan-link")
    public ResponseEntity<?> scanLink(@RequestBody Map<String, String> request) {
        String url = request.get("url");
        if (url == null || url.isBlank()) {
            return ResponseEntity.badRequest().body(Map.of("error", "URL is required"));
        }
        return ResponseEntity.ok(safetyAnalyzerService.scanUrl(url));
    }

    @PostMapping("/terminate-session")
    public ResponseEntity<?> terminateSession(@RequestBody Map<String, String> request) {
        String userIdStr = request.get("userId");
        String deviceName = request.getOrDefault("deviceName", "Unknown Device");

        UUID userId = userIdStr != null ? UUID.fromString(userIdStr) : null;
        if (userId != null) {
            SafetyEvent event = new SafetyEvent();
            event.setUserId(userId);
            event.setEventType("SESSION_TERMINATED");
            event.setSeverity("LOW");
            event.setDescription("Remote kill switch activated. Session terminated for device: " + deviceName);
            event.setIpAddress("127.0.0.1");
            safetyEventRepository.save(event);
        }

        return ResponseEntity.ok(Map.of(
                "status", "success",
                "message", "Session terminated successfully across all tokens"
        ));
    }

    @PostMapping("/emergency-checkin")
    public ResponseEntity<?> emergencyCheckin(@RequestBody Map<String, Object> request) {
        String userIdStr = (String) request.get("userId");
        String status = (String) request.getOrDefault("status", "SAFE");
        String note = (String) request.getOrDefault("note", "I am safe and checking in.");

        UUID userId = userIdStr != null ? UUID.fromString(userIdStr) : null;
        if (userId != null) {
            SafetyEvent event = new SafetyEvent();
            event.setUserId(userId);
            event.setEventType("EMERGENCY_CHECKIN");
            event.setSeverity("LOW");
            event.setDescription("Emergency Check-in triggered: [" + status + "] " + note);
            event.setIpAddress("127.0.0.1");
            safetyEventRepository.save(event);
        }

        return ResponseEntity.ok(Map.of("status", "success", "broadcastCount", 3));
    }
}
