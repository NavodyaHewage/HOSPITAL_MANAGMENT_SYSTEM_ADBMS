package com.hospital.hms.module.audit.mapper;

import com.hospital.hms.module.audit.dto.response.AuditLogResponse;
import com.hospital.hms.module.audit.entity.AuditLog;
import org.springframework.stereotype.Component;

@Component
public class AuditMapper {

    public AuditLogResponse toResponse(AuditLog log, String username) {
        return new AuditLogResponse(
                log.getLogId(),
                log.getUserId(),
                username,
                log.getEntityName(),
                log.getEntityId(),
                log.getAction() == null ? null : log.getAction().name(),
                log.getOldValue(),
                log.getNewValue(),
                log.getIpAddress(),
                log.getCreatedAt());
    }
}
