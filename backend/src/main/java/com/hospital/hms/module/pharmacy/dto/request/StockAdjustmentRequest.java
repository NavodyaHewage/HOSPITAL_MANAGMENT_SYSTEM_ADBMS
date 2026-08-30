package com.hospital.hms.module.pharmacy.dto.request;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Positive;
import jakarta.validation.constraints.Size;

/** Quantity is always positive - direction carries the sign. */
public record StockAdjustmentRequest(
        @NotNull Integer batchId,
        @NotNull @Positive Integer quantity,

        @NotBlank @Pattern(regexp = "ADD|REMOVE", message = "must be ADD or REMOVE")
        String direction,

        @Size(max = 255) String notes) {
}
