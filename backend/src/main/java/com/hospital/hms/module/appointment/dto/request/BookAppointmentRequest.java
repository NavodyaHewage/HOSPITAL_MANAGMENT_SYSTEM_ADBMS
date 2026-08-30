package com.hospital.hms.module.appointment.dto.request;

import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import java.time.LocalDate;
import java.time.LocalTime;

/**
 * Null appointmentId books a new appointment; a populated one reschedules that
 * appointment. The single stored procedure handles both, so the API does too.
 *
 * <p>There is deliberately no @FutureOrPresent on the date: the rule lives in
 * sp_book_or_reschedule_appointment and trg_appointments_bi_validate, and
 * duplicating it here would mean two places to change and a chance for them to
 * disagree. Bean Validation covers shape; the database covers rules.
 */
public record BookAppointmentRequest(
        Integer appointmentId,

        @NotNull Integer patientId,
        @NotNull Integer doctorId,
        @NotNull LocalDate appointmentDate,
        @NotNull LocalTime appointmentTime,
        @Size(max = 255) String reason) {
}
