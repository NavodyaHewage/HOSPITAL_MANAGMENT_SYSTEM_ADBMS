package com.hospital.hms.module.appointment.repository.procedure;

import com.hospital.hms.common.jdbc.StoredProcedureExecutor;
import com.hospital.hms.module.appointment.dto.request.BookAppointmentRequest;
import java.sql.Date;
import java.sql.Time;
import java.util.HashMap;
import java.util.Map;
import org.springframework.stereotype.Repository;

/**
 * Wraps sp_book_or_reschedule_appointment.
 *
 * <p>The procedure - not this class - owns the three layers that stop a double
 * booking: an X-lock on the doctor row, the fn_check_doctor_availability check,
 * and UNIQUE(active_slot_key) as the engine's final word. It raises SQLSTATE
 * 45000 with a readable message on any of them, which StoredProcedureExecutor
 * turns into a BusinessRuleException and the handler renders as HTTP 409.
 *
 * <p>Passing a null appointmentId books; passing an existing one reschedules.
 * Either way the id comes back through the INOUT parameter.
 */
@Repository
public class AppointmentProcedureRepository {

    private static final String SP_BOOK_OR_RESCHEDULE = "sp_book_or_reschedule_appointment";
    private static final String FN_COUNT_PATIENT_APPOINTMENTS = "fn_count_patient_appointments";

    private final StoredProcedureExecutor executor;

    public AppointmentProcedureRepository(StoredProcedureExecutor executor) {
        this.executor = executor;
    }

    public Integer bookOrReschedule(BookAppointmentRequest request) {
        Map<String, Object> params = new HashMap<>();
        params.put("p_appointment_id", request.appointmentId());
        params.put("p_patient_id", request.patientId());
        params.put("p_doctor_id", request.doctorId());
        params.put("p_date", Date.valueOf(request.appointmentDate()));
        params.put("p_time", Time.valueOf(request.appointmentTime()));
        params.put("p_reason", request.reason());

        Map<String, Object> out = executor.call(SP_BOOK_OR_RESCHEDULE, params);
        Object id = out.get("p_appointment_id");
        return id == null ? null : ((Number) id).intValue();
    }

    /** fn_count_patient_appointments - a null status counts every status. */
    public int countForPatient(Integer patientId, String status) {
        Integer count = executor.callFunction(FN_COUNT_PATIENT_APPOINTMENTS, Integer.class,
                patientId, status);
        return count == null ? 0 : count;
    }
}
