package com.hospital.hms.module.laboratory.dto.request;

import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

/**
 * Placing a lab order, optionally with its result already known.
 *
 * <p>Leave resultValue null to just place the order. Supply it and the
 * procedure records the result in the same transaction, which closes the order.
 */
public record LabOrderRequest(
        @NotNull Integer appointmentId,
        @NotNull Integer testId,

        @Pattern(regexp = "Routine|Urgent|Stat")
        String priority,

        @Size(max = 255) String resultValue,
        @Size(max = 100) String performedBy,
        Boolean isAbnormal) {
}
