package com.hospital.hms.module.prescription.repository.view;

import com.hospital.hms.module.prescription.entity.Prescription;
import java.util.List;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.Repository;
import org.springframework.data.repository.query.Param;

public interface PrescriptionViewRepository extends Repository<Prescription, Integer> {

    @Query(value = """
            SELECT prescription_id, patient_id, doctor_id, prescription_date, item_id,
                   medicine_id, medicine_name, dosage, frequency, duration_days, quantity
            FROM vw_active_prescriptions
            WHERE (:patientId IS NULL OR patient_id = :patientId)
            ORDER BY prescription_date DESC, item_id
            """, nativeQuery = true)
    List<ActivePrescriptionView> findActive(@Param("patientId") Integer patientId);
}
