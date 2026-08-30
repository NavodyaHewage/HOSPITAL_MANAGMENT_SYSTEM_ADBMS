package com.hospital.hms.module.billing.entity;

import jakarta.persistence.AttributeConverter;
import jakarta.persistence.Converter;
import java.util.Arrays;

/**
 * Mirrors ENUM('Cash','Card','Insurance','Bank Transfer').
 *
 * <p>"Bank Transfer" contains a space, so - as with AppointmentStatus - the
 * database spelling is carried on the constant and a converter translates.
 */
public enum PaymentMethod {

    CASH("Cash"),
    CARD("Card"),
    INSURANCE("Insurance"),
    BANK_TRANSFER("Bank Transfer");

    private final String dbValue;

    PaymentMethod(String dbValue) {
        this.dbValue = dbValue;
    }

    public String dbValue() {
        return dbValue;
    }

    public static PaymentMethod from(String value) {
        if (value == null) {
            return null;
        }
        return Arrays.stream(values())
                .filter(m -> m.dbValue.equalsIgnoreCase(value) || m.name().equalsIgnoreCase(value))
                .findFirst()
                .orElseThrow(() -> new IllegalArgumentException("Unknown payment method: " + value));
    }

    @Converter(autoApply = true)
    public static class JpaConverter implements AttributeConverter<PaymentMethod, String> {

        @Override
        public String convertToDatabaseColumn(PaymentMethod attribute) {
            return attribute == null ? null : attribute.dbValue();
        }

        @Override
        public PaymentMethod convertToEntityAttribute(String dbData) {
            return from(dbData);
        }
    }
}
