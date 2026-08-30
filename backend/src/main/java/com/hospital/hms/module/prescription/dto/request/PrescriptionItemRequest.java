package com.hospital.hms.module.prescription.dto.request;

import com.fasterxml.jackson.annotation.JsonProperty;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;
import jakarta.validation.constraints.Size;

/**
 * One line of a prescription.
 *
 * <p>The @JsonProperty names are snake_case because this record is serialised
 * straight into the p_items_json argument of sp_create_prescription_with_items,
 * and the JSON_TABLE inside that procedure reads $.medicine_id, $.duration_days
 * and so on. Renaming a field here silently produces NULL columns there.
 */
public record PrescriptionItemRequest(

        @JsonProperty("medicine_id")
        @NotNull Integer medicineId,

        @JsonProperty("dosage")
        @Size(max = 50) String dosage,

        @JsonProperty("frequency")
        @Size(max = 50) String frequency,

        @JsonProperty("duration_days")
        @Min(1) @Max(180) Integer durationDays,

        @JsonProperty("quantity")
        @NotNull @Positive Integer quantity,

        @JsonProperty("instructions")
        @Size(max = 255) String instructions) {
}
