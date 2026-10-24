package com.chatgen.backend.repository;

import com.chatgen.backend.model.CallSession;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.UUID;

@Repository
public interface CallSessionRepository extends JpaRepository<CallSession, UUID> {
    List<CallSession> findByCallerIdOrReceiverIdOrderByCreatedAtDesc(UUID callerId, UUID receiverId);
    List<CallSession> findByConversationIdOrderByCreatedAtDesc(UUID conversationId);
}
