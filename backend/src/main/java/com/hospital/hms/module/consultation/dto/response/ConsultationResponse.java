package com.hospital.hms.module.consultation.dto.response;

import java.time.LocalDate;
import java.time.LocalDateTime;

public record ConsultationResponse(
        Integer consultationId,
        Integer appointmentId,
        Integer patientId,
        String patientName,
        Integer doctorId,
        String doctorName,
        LocalDateTime consultationDate,
        String chiefComplaint,
        String diagnosis,
        String symptoms,
        String treatmentPlan,
        String notes,
        LocalDate followUpDate) {
}
