package com.chatgen.backend.repository;

import com.chatgen.backend.model.SafetyEvent;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.UUID;

@Repository
public interface SafetyEventRepository extends JpaRepository<SafetyEvent, UUID> {
    List<SafetyEvent> findByUserIdOrderByCreatedAtDesc(UUID userId);
    List<SafetyEvent> findTop20ByOrderByCreatedAtDesc();
}
