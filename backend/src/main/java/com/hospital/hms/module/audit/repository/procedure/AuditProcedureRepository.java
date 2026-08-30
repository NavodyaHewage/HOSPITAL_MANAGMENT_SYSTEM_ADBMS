package com.hospital.hms.module.audit.repository.procedure;

import com.hospital.hms.common.jdbc.StoredProcedureExecutor;
import com.hospital.hms.module.audit.dto.response.AuditReportRow;
import java.sql.Timestamp;
import java.time.LocalDateTime;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import org.springframework.stereotype.Repository;

/** Wraps sp_generate_audit_report and the two audit functions. */
@Repository
public class AuditProcedureRepository {

    private static final String SP_AUDIT_REPORT = "sp_generate_audit_report";
    private static final String FN_COUNT_EVENTS = "fn_count_audit_events";
    private static final String FN_ACTIVITY_SUMMARY = "fn_return_audit_activity_summary";

    private final StoredProcedureExecutor executor;

    public AuditProcedureRepository(StoredProcedureExecutor executor) {
        this.executor = executor;
    }

    /** A null entityName reports across every entity. */
    public List<AuditReportRow> generateReport(LocalDateTime from, LocalDateTime to,
                                               String entityName) {
        Map<String, Object> params = new HashMap<>();
        params.put("p_from", Timestamp.valueOf(from));
        params.put("p_to", Timestamp.valueOf(to));
        params.put("p_entity_name", entityName);

        return executor.callForRows(SP_AUDIT_REPORT, params).stream()
                .map(row -> new AuditReportRow(
                        (String) row.get("entity_name"),
                        String.valueOf(row.get("action")),
                        toLong(row.get("event_count")),
                        toLong(row.get("distinct_users")),
                        toDateTime(row.get("first_event")),
                        toDateTime(row.get("last_event"))))
                .toList();
    }

    /** fn_count_audit_events - half-open [from, to). */
    public int countEvents(String entityName, LocalDateTime from, LocalDateTime to) {
        Integer count = executor.callFunction(FN_COUNT_EVENTS, Integer.class,
                entityName, Timestamp.valueOf(from), Timestamp.valueOf(to));
        return count == null ? 0 : count;
    }

    /** fn_return_audit_activity_summary - a one-line human summary per user. */
    public String activitySummary(Integer userId) {
        return executor.callFunction(FN_ACTIVITY_SUMMARY, String.class, userId);
    }

    private Long toLong(Object value) {
        return value == null ? null : ((Number) value).longValue();
    }

    private LocalDateTime toDateTime(Object value) {
        if (value == null) {
            return null;
        }
        return value instanceof Timestamp timestamp
                ? timestamp.toLocalDateTime()
                : LocalDateTime.parse(value.toString().replace(' ', 'T'));
    }
}
