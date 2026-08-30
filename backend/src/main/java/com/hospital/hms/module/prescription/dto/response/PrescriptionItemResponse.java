package com.hospital.hms.module.prescription.dto.response;

public record PrescriptionItemResponse(
        Integer itemId,
        Integer medicineId,
        String medicineName,
        String dosage,
        String frequency,
        Integer durationDays,
        Integer quantity,
        String instructions) {
}
