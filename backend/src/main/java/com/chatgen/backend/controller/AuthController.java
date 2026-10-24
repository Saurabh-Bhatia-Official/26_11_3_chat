package com.chatgen.backend.controller;

import com.chatgen.backend.model.User;
import com.chatgen.backend.repository.UserRepository;
import com.chatgen.backend.service.CloudinaryService;
import com.chatgen.backend.service.JwtService;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.time.Instant;
import java.util.*;

@RestController
@RequestMapping("/api/auth")
public class AuthController {

    private final UserRepository userRepository;
    private final JwtService jwtService;
    private final CloudinaryService cloudinaryService;

    public AuthController(UserRepository userRepository, JwtService jwtService, CloudinaryService cloudinaryService) {
        this.userRepository = userRepository;
        this.jwtService = jwtService;
        this.cloudinaryService = cloudinaryService;
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

        String token = jwtService.generateToken(user);

        Map<String, Object> response = new HashMap<>();
        response.put("token", token);
        response.put("tokenType", "Bearer");
        response.put("expiresInMs", 86400000L);
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

        String token = jwtService.generateToken(saved);

        Map<String, Object> response = new HashMap<>();
        response.put("token", token);
        response.put("tokenType", "Bearer");
        response.put("expiresInMs", 86400000L);
        response.put("user", saved);
        return ResponseEntity.ok(response);
    }

    @PostMapping("/register")
    public ResponseEntity<?> register(@RequestBody Map<String, String> payload) {
        return signup(payload);
    }

    @GetMapping({"/account", "/me"})
    public ResponseEntity<?> getCurrentAccount(
            @RequestHeader(value = "Authorization", required = false) String authHeader,
            @RequestParam(required = false) String token
    ) {
        String rawToken = token != null && !token.isBlank() ? token : jwtService.extractToken(authHeader);
        if (rawToken == null || rawToken.isBlank()) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED).body(Map.of("error", "No JWT authorization token provided"));
        }

        if (!jwtService.validateToken(rawToken)) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED).body(Map.of("error", "Invalid or expired JWT token"));
        }

        UUID userId = jwtService.getUserIdFromToken(rawToken);
        if (userId == null) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED).body(Map.of("error", "Invalid token subject"));
        }

        return userRepository.findById(userId).map(user -> {
            user.setLastSeen(Instant.now());
            userRepository.save(user);

            Map<String, Object> resp = new HashMap<>();
            resp.put("authenticated", true);
            resp.put("user", user);
            resp.put("token", rawToken);
            return ResponseEntity.ok(resp);
        }).orElse(ResponseEntity.status(HttpStatus.NOT_FOUND).body(Map.of("error", "User account not found")));
    }

    @PutMapping("/account")
    public ResponseEntity<?> updateCurrentAccount(
            @RequestHeader(value = "Authorization", required = false) String authHeader,
            @RequestBody Map<String, Object> updates
    ) {
        String token = jwtService.extractToken(authHeader);
        if (token == null || !jwtService.validateToken(token)) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED).body(Map.of("error", "Unauthorized"));
        }
        UUID userId = jwtService.getUserIdFromToken(token);
        if (userId == null) return ResponseEntity.status(HttpStatus.UNAUTHORIZED).build();
        return updateProfile(userId, updates);
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
            if (updates.containsKey("username")) user.setUsername((String) updates.get("username"));
            if (updates.containsKey("email")) user.setEmail((String) updates.get("email"));
            if (updates.containsKey("phone")) user.setPhone((String) updates.get("phone"));
            if (updates.containsKey("statusMessage")) user.setStatusMessage((String) updates.get("statusMessage"));
            if (updates.containsKey("bio")) user.setBio((String) updates.get("bio"));
            if (updates.containsKey("avatarUrl")) {
                String newAvatar = (String) updates.get("avatarUrl");
                String oldAvatar = user.getAvatarUrl();
                if (oldAvatar != null && !oldAvatar.equals(newAvatar) && oldAvatar.contains("cloudinary.com")) {
                    cloudinaryService.deleteFileByUrl(oldAvatar);
                }
                user.setAvatarUrl(newAvatar);
            }
            if (updates.containsKey("themePreference")) user.setThemePreference((String) updates.get("themePreference"));
            if (updates.containsKey("appIconPreference")) user.setAppIconPreference((String) updates.get("appIconPreference"));
            if (updates.containsKey("softwareName")) user.setSoftwareName((String) updates.get("softwareName"));
            if (updates.containsKey("customLogoUrl")) {
                String newLogo = (String) updates.get("customLogoUrl");
                String oldLogo = user.getCustomLogoUrl();
                if (oldLogo != null && !oldLogo.equals(newLogo) && oldLogo.contains("cloudinary.com")) {
                    cloudinaryService.deleteFileByUrl(oldLogo);
                }
                user.setCustomLogoUrl(newLogo);
            }
            if (updates.containsKey("isPrivate")) {
                Object val = updates.get("isPrivate");
                if (val instanceof Boolean) {
                    user.setIsPrivate((Boolean) val);
                } else if (val != null) {
                    user.setIsPrivate(Boolean.parseBoolean(val.toString()));
                }
            }
            return ResponseEntity.ok(userRepository.save(user));
        }).orElse(ResponseEntity.notFound().build());
    }

    @GetMapping("/search")
    public ResponseEntity<List<Map<String, Object>>> searchUsers(
            @RequestParam(required = false, defaultValue = "") String query,
            @RequestParam(required = false) String currentUserId
    ) {
        if (query == null || query.trim().isBlank()) {
            return ResponseEntity.ok(Collections.emptyList());
        }

        String cleanQuery = query.trim().toLowerCase().replace("@", "");
        UUID callerId = null;
        if (currentUserId != null && !currentUserId.isBlank()) {
            try {
                callerId = UUID.fromString(currentUserId);
            } catch (Exception ignored) {}
        }

        final UUID excludeId = callerId;
        List<User> all = userRepository.findAll();
        List<Map<String, Object>> sanitizedResults = new ArrayList<>();

        for (User u : all) {
            if (excludeId != null && u.getId().equals(excludeId)) {
                continue;
            }
            boolean matches = (u.getUsername() != null && u.getUsername().toLowerCase().contains(cleanQuery)) ||
                              (u.getDisplayName() != null && u.getDisplayName().toLowerCase().contains(cleanQuery));
            if (matches) {
                Map<String, Object> safe = new HashMap<>();
                safe.put("id", u.getId());
                safe.put("username", u.getUsername());
                safe.put("displayName", u.getDisplayName());
                safe.put("avatarUrl", u.getAvatarUrl());
                safe.put("statusMessage", u.getStatusMessage() != null ? u.getStatusMessage() : "Available");
                safe.put("isPrivate", u.getIsPrivate());
                sanitizedResults.add(safe);
            }
        }

        return ResponseEntity.ok(sanitizedResults);
    }
}
