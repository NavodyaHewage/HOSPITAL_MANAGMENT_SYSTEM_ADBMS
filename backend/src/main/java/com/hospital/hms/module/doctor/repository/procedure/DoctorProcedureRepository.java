package com.hospital.hms.module.doctor.repository.procedure;

import com.hospital.hms.common.jdbc.StoredProcedureExecutor;
import com.hospital.hms.module.doctor.dto.response.DoctorAvailabilityResponse;
import java.math.BigDecimal;
import java.sql.Date;
import java.sql.Time;
import java.time.LocalDate;
import java.time.LocalTime;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import org.springframework.stereotype.Repository;

/** Wraps sp_search_doctor_availability and fn_check_doctor_availability. */
@Repository
public class DoctorProcedureRepository {

    private static final String SP_SEARCH_AVAILABILITY = "sp_search_doctor_availability";
    private static final String FN_CHECK_AVAILABILITY = "fn_check_doctor_availability";

    private final StoredProcedureExecutor executor;

    public DoctorProcedureRepository(StoredProcedureExecutor executor) {
        this.executor = executor;
    }

    /**
     * Doctors in the department who have that exact slot free. A null
     * departmentId means "any department" - the procedure handles it.
     */
    public List<DoctorAvailabilityResponse> searchAvailability(Integer departmentId,
                                                               LocalDate date,
                                                               LocalTime time) {
        Map<String, Object> params = new HashMap<>();
        params.put("p_department_id", departmentId);
        params.put("p_date", Date.valueOf(date));
        params.put("p_time", Time.valueOf(time));

        return executor.callForRows(SP_SEARCH_AVAILABILITY, params).stream()
                .map(row -> new DoctorAvailabilityResponse(
                        toInt(row.get("doctor_id")),
                        (String) row.get("doctor_name"),
                        (String) row.get("specialization"),
                        (BigDecimal) row.get("consultation_fee"),
                        toLong(row.get("bookings_that_day"))))
                .toList();
    }

    /**
     * Convenience check only. It is NOT a concurrency guarantee - between this
     * returning true and the INSERT landing, another session can take the slot.
     * UNIQUE(active_slot_key) is what actually prevents the double booking.
     */
    public boolean isSlotFree(Integer doctorId, LocalDate date, LocalTime time) {
        Boolean free = executor.callFunction(FN_CHECK_AVAILABILITY, Boolean.class,
                doctorId, Date.valueOf(date), Time.valueOf(time));
        return Boolean.TRUE.equals(free);
    }

    private Integer toInt(Object value) {
        return value == null ? null : ((Number) value).intValue();
    }

    private Long toLong(Object value) {
        return value == null ? null : ((Number) value).longValue();
    }
}
