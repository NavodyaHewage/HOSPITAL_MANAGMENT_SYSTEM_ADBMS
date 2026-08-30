package com.hospital.hms.module.audit.controller;

import com.hospital.hms.common.dto.ApiResponse;
import com.hospital.hms.common.dto.PageResponse;
import com.hospital.hms.module.audit.dto.response.AuditLogResponse;
import com.hospital.hms.module.audit.dto.response.AuditReportRow;
import com.hospital.hms.module.audit.repository.view.RecentAuditActivityView;
import com.hospital.hms.module.audit.service.AuditService;
import jakarta.validation.constraints.Pattern;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Map;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

/**
 * Read-only. Audit rows are written by database triggers inside the transaction
 * they describe - there is deliberately no endpoint to create, edit or delete
 * one. An audit trail the application can rewrite is not an audit trail.
 */
@RestController
@RequestMapping("/audit")
@Validated
@PreAuthorize("hasAuthority(T(com.hospital.hms.security.rbac.Permissions).AUDIT_READ)")
public class AuditController {

    private final AuditService auditService;

    public AuditController(AuditService auditService) {
        this.auditService = auditService;
    }

    @GetMapping("/logs")
    public ApiResponse<PageResponse<AuditLogResponse>> search(
            @RequestParam(required = false) String entityName,
            @RequestParam(required = false)
            @Pattern(regexp = "INSERT|UPDATE|DELETE|LOGIN|LOGOUT") String action,
            @RequestParam(required = false) Integer userId,
            @RequestParam(required = false)
            @DateTimeFormat(iso = DateTimeFormat.ISO.DATE_TIME) LocalDateTime from,
            @RequestParam(required = false)
            @DateTimeFormat(iso = DateTimeFormat.ISO.DATE_TIME) LocalDateTime to,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "50") int size) {
        return ApiResponse.ok(auditService.search(entityName, action, userId, from, to, page, size));
    }

    /** The full history of one row, e.g. /audit/trail/payments/1234. */
    @GetMapping("/trail/{entityName}/{entityId}")
    public ApiResponse<PageResponse<AuditLogResponse>> trail(
            @PathVariable String entityName,
            @PathVariable Integer entityId,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "50") int size) {
        return ApiResponse.ok(auditService.trailFor(entityName, entityId, page, size));
    }

    /** Backed by vw_recent_audit_activity (last 30 days). */
    @GetMapping("/recent")
    public ApiResponse<List<RecentAuditActivityView>> recent(
            @RequestParam(defaultValue = "100") int limit) {
        return ApiResponse.ok(auditService.recentActivity(limit));
    }

    /** Backed by sp_generate_audit_report - counts grouped by entity and action. */
    @GetMapping("/report")
    public ApiResponse<List<AuditReportRow>> report(
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE_TIME) LocalDateTime from,
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE_TIME) LocalDateTime to,
            @RequestParam(required = false) String entityName) {
        return ApiResponse.ok(auditService.report(from, to, entityName));
    }

    /** Backed by fn_count_audit_events. */
    @GetMapping("/count")
    public ApiResponse<Map<String, Integer>> count(
            @RequestParam String entityName,
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE_TIME) LocalDateTime from,
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE_TIME) LocalDateTime to) {
        return ApiResponse.ok(Map.of("count", auditService.countEvents(entityName, from, to)));
    }

    /** Backed by fn_return_audit_activity_summary. */
    @GetMapping("/summary/{userId}")
    public ApiResponse<Map<String, String>> summary(@PathVariable Integer userId) {
        return ApiResponse.ok(Map.of("summary", auditService.activitySummary(userId)));
    }
}
