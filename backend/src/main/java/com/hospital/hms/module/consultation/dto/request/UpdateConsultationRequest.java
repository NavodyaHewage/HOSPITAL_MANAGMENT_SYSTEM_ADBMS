package com.hospital.hms.module.consultation.dto.request;

/** Null fields are left untouched, so this doubles as a partial update. */
public record UpdateConsultationRequest(
        String diagnosis,
        String treatmentPlan,
        String notes) {
}
