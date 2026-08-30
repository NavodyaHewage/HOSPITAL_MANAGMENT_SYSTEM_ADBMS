package com.hospital.hms.module.appointment.dto.response;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.LocalTime;

public record AppointmentResponse(
        Integer appointmentId,
        Integer patientId,
        String patientName,
        Integer doctorId,
        String doctorName,
        LocalDate appointmentDate,
        LocalTime appointmentTime,
        String status,
        String reason,
        String notes,
        /** Non-null only while the slot is actually held - see active_slot_key. */
        String activeSlotKey,
        LocalDateTime createdAt) {
}
