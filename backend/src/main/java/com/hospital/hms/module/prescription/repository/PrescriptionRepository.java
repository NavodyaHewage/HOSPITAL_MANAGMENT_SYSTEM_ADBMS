package com.hospital.hms.module.prescription.repository;

import com.hospital.hms.module.prescription.entity.Prescription;
import com.hospital.hms.module.prescription.entity.PrescriptionStatus;
import java.util.List;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

@Repository
public interface PrescriptionRepository extends JpaRepository<Prescription, Integer> {

    Page<Prescription> findByPatientIdOrderByPrescriptionDateDesc(Integer patientId, Pageable pageable);

    Page<Prescription> findByStatusOrderByPrescriptionDateDesc(PrescriptionStatus status, Pageable pageable);

    List<Prescription> findByConsultationId(Integer consultationId);

    /** Uses idx_prescriptions_appointment_date. */
    List<Prescription> findByAppointmentIdOrderByPrescriptionDateDesc(Integer appointmentId);
}
