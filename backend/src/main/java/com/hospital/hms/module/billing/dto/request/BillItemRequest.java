package com.hospital.hms.module.billing.dto.request;

import com.fasterxml.jackson.annotation.JsonProperty;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;

/**
 * One line of a bill.
 *
 * <p>Only the service and the quantity - deliberately NO price. The procedure
 * reads unit_price from the services master, so the client cannot set its own.
 * The snake_case JSON names match the JSON_TABLE paths inside
 * sp_create_bill_with_items ($.service_id, $.quantity).
 */
public record BillItemRequest(

        @JsonProperty("service_id")
        @NotNull Integer serviceId,

        @JsonProperty("quantity")
        @NotNull @Positive Integer quantity) {
}
