package com.hospital.hms.common.jdbc;

import com.hospital.hms.common.exception.BusinessRuleException;
import java.sql.SQLException;
import java.util.List;
import java.util.Map;
import org.springframework.dao.DataAccessException;
import org.springframework.jdbc.UncategorizedSQLException;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.simple.SimpleJdbcCall;
import org.springframework.stereotype.Component;

/**
 * Thin wrapper over {@link SimpleJdbcCall} used by every *ProcedureRepository.
 *
 * <p>The schema drives its transactional work through stored procedures
 * (sp_book_or_reschedule_appointment, sp_dispense_medicine, ...), so the service
 * layer calls them here rather than re-implementing the rules in Java. Those
 * procedures run their own START TRANSACTION / COMMIT and roll themselves back
 * through an EXIT HANDLER, which is why callers must NOT wrap them in a Spring
 * {@code @Transactional} - doing so nests a Spring transaction around a
 * procedure that already committed, and the two disagree about what is durable.
 */
@Component
public class StoredProcedureExecutor {

    /** Key under which SimpleJdbcCall exposes the first returned result set. */
    private static final String FIRST_RESULT_SET = "#result-set-1";

    private final JdbcTemplate jdbcTemplate;

    public StoredProcedureExecutor(JdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    /** Calls a procedure and returns its OUT/INOUT parameters. */
    public Map<String, Object> call(String procedureName, Map<String, ?> params) {
        try {
            return new SimpleJdbcCall(jdbcTemplate)
                    .withProcedureName(procedureName)
                    .execute(params);
        } catch (DataAccessException ex) {
            throw translate(ex);
        }
    }

    /**
     * Calls a procedure whose payload is a SELECT (sp_search_doctor_availability,
     * sp_generate_audit_report) and returns that result set as raw rows.
     */
    @SuppressWarnings("unchecked")
    public List<Map<String, Object>> callForRows(String procedureName, Map<String, ?> params) {
        Map<String, Object> out = call(procedureName, params);
        Object rows = out.get(FIRST_RESULT_SET);
        return rows instanceof List<?> list ? (List<Map<String, Object>>) list : List.of();
    }

    /**
     * Evaluates a stored FUNCTION - fn_calculate_available_stock,
     * fn_check_user_permission and friends. Kept here so the SQLSTATE 45000
     * translation applies uniformly to every routine call.
     */
    public <T> T callFunction(String functionName, Class<T> returnType, Object... args) {
        String placeholders = args.length == 0 ? ""
                : String.join(", ", java.util.Collections.nCopies(args.length, "?"));
        String sql = "SELECT %s(%s)".formatted(functionName, placeholders);
        try {
            return jdbcTemplate.queryForObject(sql, returnType, args);
        } catch (DataAccessException ex) {
            throw translate(ex);
        }
    }

    /**
     * MySQL's SIGNAL SQLSTATE '45000' carries the human-readable business rule
     * message ("STOCK CANNOT GO NEGATIVE", "Payment exceeds the outstanding
     * balance", ...). Surface it to the client instead of a generic 500 - the
     * schema wrote those messages to be read by a human.
     */
    private RuntimeException translate(DataAccessException ex) {
        SQLException cause = ex instanceof UncategorizedSQLException uncategorized
                ? uncategorized.getSQLException()
                : findSqlException(ex);

        if (cause != null && "45000".equals(cause.getSQLState())) {
            return new BusinessRuleException(stripPrefix(cause.getMessage()));
        }
        return ex;
    }

    private SQLException findSqlException(Throwable ex) {
        for (Throwable t = ex; t != null; t = t.getCause()) {
            if (t instanceof SQLException sqlException) {
                return sqlException;
            }
        }
        return null;
    }

    /** The driver prefixes SIGNAL messages; the rule text is what matters. */
    private String stripPrefix(String message) {
        if (message == null) {
            return "Business rule violated";
        }
        int marker = message.indexOf("] ");
        return marker >= 0 ? message.substring(marker + 2) : message;
    }
}
