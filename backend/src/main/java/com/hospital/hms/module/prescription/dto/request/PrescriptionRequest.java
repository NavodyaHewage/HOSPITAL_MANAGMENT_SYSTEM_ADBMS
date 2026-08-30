package com.hospital.hms.module.prescription.dto.request;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.NotNull;
import java.util.List;

public record PrescriptionRequest(
        @NotNull Integer consultationId,

        @NotEmpty(message = "A prescription must have at least one item")
        @Valid List<PrescriptionItemRequest> items,

        String notes) {
}
