package com.hospital.hms.module.audit.dto.response;

import java.time.LocalDateTime;

public record AuditLogResponse(
        Integer logId,
        Integer userId,
        String username,
        String entityName,
        Integer entityId,
        String action,
        String oldValue,
        String newValue,
        String ipAddress,
        LocalDateTime createdAt) {
}
