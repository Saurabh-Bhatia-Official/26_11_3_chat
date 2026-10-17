package com.chatgen.backend.repository;

import com.chatgen.backend.model.Conversation;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface ConversationRepository extends JpaRepository<Conversation, UUID> {
    List<Conversation> findAllByOrderByLastMessageAtDesc();
    List<Conversation> findByParticipant1IdOrParticipant2IdOrderByLastMessageAtDesc(UUID p1, UUID p2);
    Optional<Conversation> findFirstByParticipant1IdAndParticipant2Id(UUID p1, UUID p2);
}
