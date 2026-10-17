package com.chatgen.backend.repository;

import com.chatgen.backend.model.GameRoom;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface GameRoomRepository extends JpaRepository<GameRoom, UUID> {
    Optional<GameRoom> findTopByConversationIdAndStatusOrderByCreatedAtDesc(UUID conversationId, String status);
    List<GameRoom> findByConversationIdOrderByCreatedAtDesc(UUID conversationId);
}
