package com.chatgen.backend.repository;

import com.chatgen.backend.model.SystemBranding;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

@Repository
public interface SystemBrandingRepository extends JpaRepository<SystemBranding, String> {
}
