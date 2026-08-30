package com.hospital.hms.module.audit.repository;

import com.hospital.hms.module.audit.entity.AuditAction;
import com.hospital.hms.module.audit.entity.AuditLog;
import java.time.LocalDateTime;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

@Repository
public interface AuditLogRepository extends JpaRepository<AuditLog, Integer> {

    /**
     * The date bounds are half-open [from, to) so the predicate stays SARGable
     * and idx_audit_logs_created_at can be used as a range scan. Wrapping
     * created_at in DATE() here would defeat the index entirely.
     */
    @Query("""
            SELECT a FROM AuditLog a
            WHERE (:entityName IS NULL OR a.entityName = :entityName)
              AND (:action IS NULL OR a.action = :action)
              AND (:userId IS NULL OR a.userId = :userId)
              AND (CAST(:from AS timestamp) IS NULL OR a.createdAt >= :from)
              AND (CAST(:to   AS timestamp) IS NULL OR a.createdAt <  :to)
            """)
    Page<AuditLog> search(@Param("entityName") String entityName,
                          @Param("action") AuditAction action,
                          @Param("userId") Integer userId,
                          @Param("from") LocalDateTime from,
                          @Param("to") LocalDateTime to,
                          Pageable pageable);

    Page<AuditLog> findByEntityNameAndEntityIdOrderByCreatedAtDesc(String entityName,
                                                                   Integer entityId,
                                                                   Pageable pageable);
}
