package com.hospital.hms.module.appointment.repository.view;

import com.hospital.hms.module.appointment.entity.Appointment;
import java.time.LocalDate;
import java.util.List;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.Repository;
import org.springframework.data.repository.query.Param;

/**
 * Reads the three appointment views. They are queried natively rather than
 * mapped as entities so JPA never attempts to write to them, and so the SQL the
 * examiner sees in the log is literally the view defined in 04_views.sql.
 *
 * <p>Deliberately extends the marker {@code Repository} rather than
 * {@code JpaRepository}: there is no save/delete to expose on a view.
 *
 * <p>ORDER BY lives here and not inside the view - a view's ORDER BY is
 * discardable when the view is merged into an outer query, and it blocks the
 * MERGE algorithm.
 */
public interface AppointmentViewRepository extends Repository<Appointment, Integer> {

    @Query(value = """
            SELECT appointment_id, patient_id, patient_name, doctor_id, doctor_name,
                   department_name, appointment_date, appointment_time, status
            FROM vw_upcoming_appointments
            WHERE (:doctorId IS NULL OR doctor_id = :doctorId)
            ORDER BY appointment_date, appointment_time
            LIMIT :limit
            """, nativeQuery = true)
    List<UpcomingAppointmentView> findUpcoming(@Param("doctorId") Integer doctorId,
                                               @Param("limit") int limit);

    @Query(value = """
            SELECT doctor_id, doctor_name, appointment_date, appointment_time,
                   status, patient_id, patient_name, reason
            FROM vw_doctor_daily_schedule
            WHERE doctor_id = :doctorId AND appointment_date = :date
            ORDER BY appointment_time
            """, nativeQuery = true)
    List<DoctorDailyScheduleView> findDoctorSchedule(@Param("doctorId") Integer doctorId,
                                                     @Param("date") LocalDate date);

    @Query(value = """
            SELECT patient_id, patient_name, appointment_id, appointment_date,
                   appointment_time, doctor_name, status, reason
            FROM vw_patient_appointment_history
            WHERE patient_id = :patientId
            ORDER BY appointment_date DESC, appointment_time DESC
            """, nativeQuery = true)
    List<PatientAppointmentHistoryView> findPatientHistory(@Param("patientId") Integer patientId);
}
