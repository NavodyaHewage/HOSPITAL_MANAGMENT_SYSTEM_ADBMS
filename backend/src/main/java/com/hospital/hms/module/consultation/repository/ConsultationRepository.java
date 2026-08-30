package com.hospital.hms.module.consultation.repository;

import com.hospital.hms.module.consultation.entity.Consultation;
import java.time.LocalDate;
import java.util.List;
import java.util.Optional;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

@Repository
public interface ConsultationRepository extends JpaRepository<Consultation, Integer> {

    Optional<Consultation> findByAppointmentId(Integer appointmentId);

    boolean existsByAppointmentId(Integer appointmentId);

    Page<Consultation> findByPatientIdOrderByConsultationDateDesc(Integer patientId, Pageable pageable);

    Page<Consultation> findByDoctorIdOrderByConsultationDateDesc(Integer doctorId, Pageable pageable);

    List<Consultation> findByFollowUpDate(LocalDate followUpDate);
}
