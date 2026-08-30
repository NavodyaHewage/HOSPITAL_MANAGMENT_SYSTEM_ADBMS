package com.hospital.hms.module.audit.service;

import com.hospital.hms.common.dto.PageResponse;
import com.hospital.hms.module.audit.dto.response.AuditLogResponse;
import com.hospital.hms.module.audit.dto.response.AuditReportRow;
import com.hospital.hms.module.audit.repository.view.RecentAuditActivityView;
import java.time.LocalDateTime;
import java.util.List;

public interface AuditService {

    PageResponse<AuditLogResponse> search(String entityName, String action, Integer userId,
                                          LocalDateTime from, LocalDateTime to,
                                          int page, int size);

    PageResponse<AuditLogResponse> trailFor(String entityName, Integer entityId, int page, int size);

    List<RecentAuditActivityView> recentActivity(int limit);

    List<AuditReportRow> report(LocalDateTime from, LocalDateTime to, String entityName);

    int countEvents(String entityName, LocalDateTime from, LocalDateTime to);

    String activitySummary(Integer userId);
}
