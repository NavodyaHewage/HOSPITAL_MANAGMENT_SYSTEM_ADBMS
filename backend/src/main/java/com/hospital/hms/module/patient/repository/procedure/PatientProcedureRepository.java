package com.hospital.hms.module.patient.repository.procedure;

import com.hospital.hms.common.jdbc.StoredProcedureExecutor;
import com.hospital.hms.module.patient.dto.request.PatientRequest;
import java.util.HashMap;
import java.util.Map;
import org.springframework.stereotype.Repository;

/**
 * Wraps sp_register_or_update_patient. The procedure owns the upsert decision
 * and the date-of-birth rule, and returns the id through its INOUT parameter.
 */
@Repository
public class PatientProcedureRepository {

    private static final String SP_REGISTER_OR_UPDATE = "sp_register_or_update_patient";

    private final StoredProcedureExecutor executor;

    public PatientProcedureRepository(StoredProcedureExecutor executor) {
        this.executor = executor;
    }

    public Integer registerOrUpdate(PatientRequest request) {
        Map<String, Object> params = new HashMap<>();
        params.put("p_patient_id", request.patientId());
        params.put("p_first_name", request.firstName());
        params.put("p_last_name", request.lastName());
        params.put("p_date_of_birth", java.sql.Date.valueOf(request.dateOfBirth()));
        params.put("p_gender", request.gender());
        params.put("p_blood_group", request.bloodGroup());
        params.put("p_phone", request.phone());
        params.put("p_email", request.email());
        params.put("p_address", request.address());
        params.put("p_emergency_name", request.emergencyContactName());
        params.put("p_emergency_phone", request.emergencyContactPhone());
        params.put("p_national_id", request.nationalId());

        Map<String, Object> out = executor.call(SP_REGISTER_OR_UPDATE, params);
        return ((Number) out.get("p_patient_id")).intValue();
    }
}
