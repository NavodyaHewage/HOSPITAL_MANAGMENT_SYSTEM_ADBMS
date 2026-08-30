package com.hospital.hms.module.consultation.dto.request;

import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import java.time.LocalDate;

public record ConsultationRequest(
        @NotNull Integer appointmentId,
        @Size(max = 255) String chiefComplaint,
        String diagnosis,
        String symptoms,
        String treatmentPlan,
        LocalDate followUpDate) {
}
