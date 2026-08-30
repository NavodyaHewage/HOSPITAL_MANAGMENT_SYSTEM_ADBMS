package com.hospital.hms.module.pharmacy.dto.request;

import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.Future;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;
import jakarta.validation.constraints.Size;
import java.math.BigDecimal;
import java.time.LocalDate;

public record ReceiveStockRequest(
        @NotNull Integer medicineId,
        @NotBlank @Size(max = 50) String batchNumber,
        @NotNull @Positive Integer quantity,
        LocalDate manufactureDate,

        /** The procedure refuses already-expired stock; this catches it earlier. */
        @NotNull @Future LocalDate expiryDate,

        @Size(max = 100) String supplierName,
        @DecimalMin("0.0") BigDecimal purchasePrice) {
}
