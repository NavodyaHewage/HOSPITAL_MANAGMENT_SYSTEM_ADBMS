package com.hospital.hms.module.appointment.repository;

import com.hospital.hms.module.appointment.entity.Appointment;
import com.hospital.hms.module.appointment.entity.AppointmentStatus;
import java.time.LocalDate;
import java.util.List;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

/** Read side. Booking and rescheduling go through AppointmentProcedureRepository. */
@Repository
public interface AppointmentRepository extends JpaRepository<Appointment, Integer> {

    /** Uses idx_appointments_patient_status. */
    Page<Appointment> findByPatientIdOrderByAppointmentDateDesc(Integer patientId, Pageable pageable);

    /** Uses idx_appointments_doctor_datetime - the doctor's diary for one day. */
    List<Appointment> findByDoctorIdAndAppointmentDateOrderByAppointmentTime(Integer doctorId,
                                                                             LocalDate appointmentDate);

    @Query("""
            SELECT a FROM Appointment a
            WHERE (:doctorId IS NULL OR a.doctorId = :doctorId)
              AND (:patientId IS NULL OR a.patientId = :patientId)
              AND (:status IS NULL OR a.status = :status)
              AND (CAST(:fromDate AS date) IS NULL OR a.appointmentDate >= :fromDate)
              AND (CAST(:toDate AS date) IS NULL OR a.appointmentDate <= :toDate)
            """)
    Page<Appointment> search(@Param("doctorId") Integer doctorId,
                             @Param("patientId") Integer patientId,
                             @Param("status") AppointmentStatus status,
                             @Param("fromDate") LocalDate fromDate,
                             @Param("toDate") LocalDate toDate,
                             Pageable pageable);

    long countByPatientIdAndStatus(Integer patientId, AppointmentStatus status);
}
