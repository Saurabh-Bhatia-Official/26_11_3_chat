package com.chatgen.backend;

import com.chatgen.backend.model.User;
import com.chatgen.backend.repository.UserRepository;
import org.springframework.boot.CommandLineRunner;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.context.annotation.Bean;

@SpringBootApplication
public class ChatApplication {

    public static void main(String[] args) {
        SpringApplication.run(ChatApplication.class, args);
    }

    @Bean
    public CommandLineRunner initDatabase(UserRepository userRepository) {
        return args -> {
            if (userRepository.count() == 0) {
                User alex = new User();
                alex.setUsername("alex_rivers");
                alex.setDisplayName("Alex Rivers");
                alex.setEmail("alex@chatguard.io");
                alex.setAvatarUrl("https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=150");
                alex.setStatusMessage("Shields up! 🛡️");
                alex.setBio("Cybersecurity advocate & chess grandmaster ♟️");
                alex.setSafetyScore(98);
                alex.setIsAdmin(true);
                userRepository.save(alex);

                User elena = new User();
                elena.setUsername("elena_rostova");
                elena.setDisplayName("Elena Rostova");
                elena.setEmail("elena@chatguard.io");
                elena.setAvatarUrl("https://images.unsplash.com/photo-1517841905240-472988babdf9?w=150");
                elena.setStatusMessage("Coding the future 💻");
                elena.setBio("Flutter & Spring Boot enthusiast ✨");
                elena.setSafetyScore(95);
                userRepository.save(elena);

                User marcus = new User();
                marcus.setUsername("marcus_vance");
                marcus.setDisplayName("Marcus Vance");
                marcus.setEmail("marcus@chatguard.io");
                marcus.setAvatarUrl("https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=150");
                marcus.setStatusMessage("Ready for a game! ⚔️");
                marcus.setBio("Ludo king & board game strategist 🎲");
                marcus.setSafetyScore(89);
                userRepository.save(marcus);
            }
        };
    }
}
