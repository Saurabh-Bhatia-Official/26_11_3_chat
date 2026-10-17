package com.chatgen.backend.controller;

import com.chatgen.backend.model.SafetyEvent;
import com.chatgen.backend.model.User;
import com.chatgen.backend.repository.ConversationRepository;
import com.chatgen.backend.repository.MessageRepository;
import com.chatgen.backend.repository.SafetyEventRepository;
import com.chatgen.backend.repository.UserRepository;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;

@RestController
@RequestMapping("/api/admin")
public class AdminController {

    private final UserRepository userRepository;
    private final ConversationRepository conversationRepository;
    private final MessageRepository messageRepository;
    private final SafetyEventRepository safetyEventRepository;

    private final Map<String, Boolean> featureFlags = new HashMap<>(Map.of(
            "playtogether_games", true,
            "voice_video_calling", true,
            "smart_safety_guardian", true,
            "dynamic_app_identity", true,
            "cloudinary_media_upload", true
    ));

    public AdminController(UserRepository userRepository,
                           ConversationRepository conversationRepository,
                           MessageRepository messageRepository,
                           SafetyEventRepository safetyEventRepository) {
        this.userRepository = userRepository;
        this.conversationRepository = conversationRepository;
        this.messageRepository = messageRepository;
        this.safetyEventRepository = safetyEventRepository;
    }

    @GetMapping("/overview")
    public ResponseEntity<Map<String, Object>> getSystemOverview() {
        Map<String, Object> stats = new HashMap<>();
        stats.put("totalUsers", userRepository.count());
        stats.put("totalConversations", conversationRepository.count());
        stats.put("totalMessages", messageRepository.count());
        stats.put("totalSafetyAlerts", safetyEventRepository.count());
        stats.put("serverStatus", "HEALTHY");
        stats.put("featureFlags", featureFlags);
        return ResponseEntity.ok(stats);
    }

    @GetMapping("/users")
    public ResponseEntity<List<User>> getUsers() {
        return ResponseEntity.ok(userRepository.findAll());
    }

    @GetMapping("/safety-alerts")
    public ResponseEntity<List<SafetyEvent>> getSafetyAlerts() {
        return ResponseEntity.ok(safetyEventRepository.findTop20ByOrderByCreatedAtDesc());
    }

    @PostMapping("/feature-flags")
    public ResponseEntity<?> toggleFeatureFlag(@RequestBody Map<String, Boolean> updates) {
        featureFlags.putAll(updates);
        return ResponseEntity.ok(featureFlags);
    }
}
