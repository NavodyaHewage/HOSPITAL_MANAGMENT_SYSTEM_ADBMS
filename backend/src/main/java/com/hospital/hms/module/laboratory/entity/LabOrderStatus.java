package com.hospital.hms.module.laboratory.entity;

import jakarta.persistence.AttributeConverter;
import jakarta.persistence.Converter;
import java.util.Arrays;

/**
 * Mirrors ENUM('Pending','In-Progress','Completed','Cancelled').
 *
 * <p>"In-Progress" is not a legal Java identifier, so - exactly as with
 * AppointmentStatus - each constant carries its database spelling and a
 * converter translates. EnumType.STRING would persist "IN_PROGRESS" and the
 * column would reject it.
 */
public enum LabOrderStatus {

    PENDING("Pending"),
    IN_PROGRESS("In-Progress"),
    COMPLETED("Completed"),
    CANCELLED("Cancelled");

    private final String dbValue;

    LabOrderStatus(String dbValue) {
        this.dbValue = dbValue;
    }

    public String dbValue() {
        return dbValue;
    }

    public static LabOrderStatus from(String value) {
        if (value == null) {
            return null;
        }
        return Arrays.stream(values())
                .filter(s -> s.dbValue.equalsIgnoreCase(value) || s.name().equalsIgnoreCase(value))
                .findFirst()
                .orElseThrow(() -> new IllegalArgumentException("Unknown lab order status: " + value));
    }

    /** Pending and In-Progress both count as outstanding work. */
    public boolean isOutstanding() {
        return this == PENDING || this == IN_PROGRESS;
    }

    @Converter(autoApply = true)
    public static class JpaConverter implements AttributeConverter<LabOrderStatus, String> {

        @Override
        public String convertToDatabaseColumn(LabOrderStatus attribute) {
            return attribute == null ? null : attribute.dbValue();
        }

        @Override
        public LabOrderStatus convertToEntityAttribute(String dbData) {
            return from(dbData);
        }
    }
}
