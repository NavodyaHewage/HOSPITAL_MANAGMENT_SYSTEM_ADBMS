package com.hospital.hms.module.audit.repository.view;

import com.hospital.hms.module.audit.entity.AuditLog;
import java.util.List;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.Repository;
import org.springframework.data.repository.query.Param;

public interface AuditViewRepository extends Repository<AuditLog, Integer> {

    /**
     * The view deliberately carries no LIMIT or ORDER BY - a LIMIT inside a view
     * forces the TEMPTABLE algorithm and blocks predicate push-down. Both are
     * applied here instead.
     */
    @Query(value = """
            SELECT log_id, user_id, username, entity_name, entity_id,
                   action, ip_address, created_at
            FROM vw_recent_audit_activity
            ORDER BY created_at DESC
            LIMIT :limit
            """, nativeQuery = true)
    List<RecentAuditActivityView> findRecent(@Param("limit") int limit);
}
