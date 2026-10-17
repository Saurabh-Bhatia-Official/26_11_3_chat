package com.chatgen.backend.controller;

import com.chatgen.backend.model.User;
import com.chatgen.backend.repository.UserRepository;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.time.Instant;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;

@RestController
@RequestMapping("/api/auth")
public class AuthController {

    private final UserRepository userRepository;

    public AuthController(UserRepository userRepository) {
        this.userRepository = userRepository;
    }

    @PostMapping("/login")
    public ResponseEntity<?> login(@RequestBody Map<String, String> credentials) {
        String username = credentials.get("username");
        String password = credentials.get("password");

        if (username == null || username.isBlank()) {
            return ResponseEntity.badRequest().body(Map.of("error", "Username is required"));
        }

        Optional<User> existing = userRepository.findByUsername(username.trim());
        if (existing.isEmpty()) {
            return ResponseEntity.status(401).body(Map.of("error", "User not found. Please sign up."));
        }

        User user = existing.get();
        if (user.getPassword() != null && !user.getPassword().isBlank() && password != null) {
            if (!user.getPassword().equals(password)) {
                return ResponseEntity.status(401).body(Map.of("error", "Incorrect password"));
            }
        }

        user.setLastSeen(Instant.now());
        userRepository.save(user);

        Map<String, Object> response = new HashMap<>();
        response.put("token", "jwt_token_" + user.getId());
        response.put("user", user);
        return ResponseEntity.ok(response);
    }

    @PostMapping("/signup")
    public ResponseEntity<?> signup(@RequestBody Map<String, String> payload) {
        String username = payload.get("username");
        String displayName = payload.get("displayName");
        String email = payload.get("email");
        String password = payload.get("password");

        if (username == null || username.isBlank()) {
            return ResponseEntity.badRequest().body(Map.of("error", "Username is required"));
        }

        if (userRepository.findByUsername(username.trim()).isPresent()) {
            return ResponseEntity.badRequest().body(Map.of("error", "Username is already registered"));
        }

        User newUser = new User();
        newUser.setUsername(username.trim());
        newUser.setDisplayName(displayName != null && !displayName.isBlank() ? displayName.trim() : username.trim());
        newUser.setEmail(email != null && !email.isBlank() ? email.trim() : username.trim() + "@chat.io");
        newUser.setPassword(password);
        newUser.setAvatarUrl("https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=150");
        newUser.setIsVerified(true);
        newUser.setSafetyScore(95);

        User saved = userRepository.save(newUser);
        Map<String, Object> response = new HashMap<>();
        response.put("token", "jwt_token_" + saved.getId());
        response.put("user", saved);
        return ResponseEntity.ok(response);
    }

    @PostMapping("/register")
    public ResponseEntity<?> register(@RequestBody Map<String, String> payload) {
        return signup(payload);
    }

    @GetMapping("/users")
    public ResponseEntity<List<User>> getAllUsers() {
        return ResponseEntity.ok(userRepository.findAll());
    }

    @GetMapping("/profile/{id}")
    public ResponseEntity<?> getProfile(@PathVariable UUID id) {
        return userRepository.findById(id)
                .map(ResponseEntity::ok)
                .orElse(ResponseEntity.notFound().build());
    }

    @PutMapping("/profile/{id}")
    public ResponseEntity<?> updateProfile(@PathVariable UUID id, @RequestBody Map<String, Object> updates) {
        return userRepository.findById(id).map(user -> {
            if (updates.containsKey("displayName")) user.setDisplayName((String) updates.get("displayName"));
            if (updates.containsKey("statusMessage")) user.setStatusMessage((String) updates.get("statusMessage"));
            if (updates.containsKey("bio")) user.setBio((String) updates.get("bio"));
            if (updates.containsKey("avatarUrl")) user.setAvatarUrl((String) updates.get("avatarUrl"));
            if (updates.containsKey("themePreference")) user.setThemePreference((String) updates.get("themePreference"));
            if (updates.containsKey("appIconPreference")) user.setAppIconPreference((String) updates.get("appIconPreference"));
            return ResponseEntity.ok(userRepository.save(user));
        }).orElse(ResponseEntity.notFound().build());
    }
}
