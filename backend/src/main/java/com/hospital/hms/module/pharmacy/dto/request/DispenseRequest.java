package com.hospital.hms.module.pharmacy.dto.request;

import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;

public record DispenseRequest(
        @NotNull Integer prescriptionId,
        @NotNull Integer medicineId,
        @NotNull @Positive Integer quantity) {
}
