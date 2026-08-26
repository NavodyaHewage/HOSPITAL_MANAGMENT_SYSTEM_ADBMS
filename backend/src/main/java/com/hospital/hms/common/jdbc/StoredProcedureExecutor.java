package com.hospital.hms.common.jdbc;

import com.hospital.hms.common.exception.BusinessRuleException;
import java.sql.SQLException;
import java.util.Map;
import org.springframework.jdbc.UncategorizedSQLException;
import org.springframework.jdbc.core.simple.SimpleJdbcCall;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Component;

/**
 * Thin wrapper over {@link SimpleJdbcCall} used by every *ProcedureRepository.
 * The schema drives its transactional work through stored procedures
 * (sp_book_or_reschedule_appointment, sp_dispense_medicine, ...), so the
 * service layer calls them here rather than re-implementing the rules in Java.
 */
@Component
public class StoredProcedureExecutor {

    private final JdbcTemplate jdbcTemplate;

    public StoredProcedureExecutor(JdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    public Map<String, Object> call(String procedureName, Map<String, ?> params) {
        try {
            SimpleJdbcCall call = new SimpleJdbcCall(jdbcTemplate).withProcedureName(procedureName);
            return call.execute(params);
        } catch (UncategorizedSQLException ex) {
            throw translate(ex);
        }
    }

    /** MySQL SIGNAL SQLSTATE '45000' carries the human-readable rule message. */
    private RuntimeException translate(UncategorizedSQLException ex) {
        SQLException cause = ex.getSQLException();
        if (cause != null && "45000".equals(cause.getSQLState())) {
            return new BusinessRuleException(cause.getMessage());
        }
        return ex;
    }
}
