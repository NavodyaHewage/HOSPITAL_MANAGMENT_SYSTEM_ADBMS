package com.hospital.hms.module.consultation.repository.procedure;

import com.hospital.hms.common.jdbc.StoredProcedureExecutor;
import com.hospital.hms.module.consultation.dto.request.ConsultationRequest;
import java.sql.Date;
import java.util.HashMap;
import java.util.Map;
import org.springframework.stereotype.Repository;

/**
 * Wraps sp_create_consultation.
 *
 * <p>The procedure locks the appointment row FOR UPDATE, refuses to consult on
 * a cancelled or no-show appointment, inserts the consultation and flips the
 * appointment to Completed - all in one transaction. Doing that here in Java
 * would be three round trips with a race between them.
 */
@Repository
public class ConsultationProcedureRepository {

    private static final String SP_CREATE_CONSULTATION = "sp_create_consultation";

    private final StoredProcedureExecutor executor;

    public ConsultationProcedureRepository(StoredProcedureExecutor executor) {
        this.executor = executor;
    }

    public Integer create(ConsultationRequest request) {
        Map<String, Object> params = new HashMap<>();
        params.put("p_consultation_id", null);
        params.put("p_appointment_id", request.appointmentId());
        params.put("p_chief_complaint", request.chiefComplaint());
        params.put("p_diagnosis", request.diagnosis());
        params.put("p_symptoms", request.symptoms());
        params.put("p_treatment_plan", request.treatmentPlan());
        params.put("p_follow_up_date",
                request.followUpDate() == null ? null : Date.valueOf(request.followUpDate()));

        Map<String, Object> out = executor.call(SP_CREATE_CONSULTATION, params);
        Object id = out.get("p_consultation_id");
        return id == null ? null : ((Number) id).intValue();
    }
}
