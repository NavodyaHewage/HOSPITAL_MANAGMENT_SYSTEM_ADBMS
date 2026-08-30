package com.hospital.hms.module.audit.repository.view;

import java.time.LocalDateTime;

/** Projection over vw_recent_audit_activity (last 30 days). */
public interface RecentAuditActivityView {

    Integer getLogId();

    Integer getUserId();

    String getUsername();

    String getEntityName();

    Integer getEntityId();

    String getAction();

    String getIpAddress();

    LocalDateTime getCreatedAt();
}
