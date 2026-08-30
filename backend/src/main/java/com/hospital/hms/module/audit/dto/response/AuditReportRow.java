package com.hospital.hms.module.audit.dto.response;

import java.time.LocalDateTime;

/** One row of sp_generate_audit_report. */
public record AuditReportRow(
        String entityName,
        String action,
        Long eventCount,
        Long distinctUsers,
        LocalDateTime firstEvent,
        LocalDateTime lastEvent) {
}
