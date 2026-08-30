package com.hospital.hms.module.consultation.repository.view;

import com.hospital.hms.module.consultation.entity.Consultation;
import java.util.List;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.Repository;
import org.springframework.data.repository.query.Param;

public interface ConsultationViewRepository extends Repository<Consultation, Integer> {

    @Query(value = """
            SELECT patient_id, consultation_id, appointment_id, consultation_date,
                   chief_complaint, diagnosis, follow_up_date, doctor_id, doctor_name
            FROM vw_patient_clinical_history
            WHERE patient_id = :patientId
            ORDER BY consultation_date DESC
            """, nativeQuery = true)
    List<PatientClinicalHistoryView> findClinicalHistory(@Param("patientId") Integer patientId);
}
