package com.chatgen.backend.repository;

import com.chatgen.backend.model.CallSession;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.Collection;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface CallSessionRepository extends JpaRepository<CallSession, UUID> {
    List<CallSession> findByCallerIdOrReceiverIdOrderByCreatedAtDesc(UUID callerId, UUID receiverId);
    List<CallSession> findByConversationIdOrderByCreatedAtDesc(UUID conversationId);

    @Query("SELECT c FROM CallSession c WHERE (c.callerId = :userId OR c.receiverId = :userId) AND c.status IN :statuses ORDER BY c.createdAt DESC")
    List<CallSession> findActiveSessionsForUser(@Param("userId") UUID userId, @Param("statuses") Collection<String> statuses);

    Optional<CallSession> findFirstByReceiverIdAndStatusOrderByCreatedAtDesc(UUID receiverId, String status);
    Optional<CallSession> findFirstByCallerIdAndStatusOrderByCreatedAtDesc(UUID callerId, String status);
}
