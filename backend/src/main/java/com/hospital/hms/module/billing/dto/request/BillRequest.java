package com.hospital.hms.module.billing.dto.request;

import jakarta.validation.Valid;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.NotNull;
import java.math.BigDecimal;
import java.util.List;

public record BillRequest(
        @NotNull Integer patientId,
        Integer appointmentId,

        @NotEmpty(message = "A bill must have at least one item")
        @Valid List<BillItemRequest> items,

        @DecimalMin("0.0") BigDecimal discount,

        /** Percentage, e.g. 2.00 for 2%. */
        @DecimalMin("0.0") BigDecimal taxRate) {
}
