package com.chatgen.backend.config;

import com.chatgen.backend.model.User;
import com.chatgen.backend.repository.UserRepository;
import org.springframework.boot.CommandLineRunner;
import org.springframework.stereotype.Component;

import java.time.Instant;

@Component
public class DataInitializer implements CommandLineRunner {

    private final UserRepository userRepository;

    public DataInitializer(UserRepository userRepository) {
        this.userRepository = userRepository;
    }

    @Override
    public void run(String... args) {
        if (userRepository.count() == 0) {
            System.out.println(">>> [SEED DATA] Initializing default demo users for local chat database...");

            createUser("alice", "Alice", "alice@chat.io", "password",
                    "https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=150");

            createUser("bob", "Bob", "bob@chat.io", "password",
                    "https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=150");

            createUser("charlie", "Charlie", "charlie@chat.io", "password",
                    "https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=150");

            createUser("admin", "Administrator", "admin@chat.io", "admin123",
                    "https://images.unsplash.com/photo-1570295999919-56ceb5ecca61?w=150");

            System.out.println(">>> [SEED DATA] Ready! Default accounts: alice/password, bob/password, admin/admin123");
        }
    }

    private void createUser(String username, String displayName, String email, String password, String avatarUrl) {
        User u = new User();
        u.setUsername(username);
        u.setDisplayName(displayName);
        u.setEmail(email);
        u.setPassword(password);
        u.setAvatarUrl(avatarUrl);
        u.setIsVerified(true);
        u.setSafetyScore(98);
        u.setStatusMessage("Available to chat");
        u.setCreatedAt(Instant.now());
        u.setLastSeen(Instant.now());
        userRepository.save(u);
    }
}
