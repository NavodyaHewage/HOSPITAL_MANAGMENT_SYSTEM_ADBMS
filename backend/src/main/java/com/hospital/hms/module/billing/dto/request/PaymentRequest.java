package com.hospital.hms.module.billing.dto.request;

import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;
import java.math.BigDecimal;

public record PaymentRequest(
        @NotNull @DecimalMin(value = "0.01", message = "Payment amount must be greater than zero")
        BigDecimal amount,

        @NotBlank @Pattern(regexp = "Cash|Card|Insurance|Bank Transfer")
        String paymentMethod,

        @Size(max = 50) String referenceNumber,

        /** When true, an available insurance credit is applied first. */
        Boolean applyInsurance) {
}
