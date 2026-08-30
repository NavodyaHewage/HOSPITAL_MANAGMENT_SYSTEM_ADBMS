package com.hospital.hms.module.appointment.entity;

import jakarta.persistence.AttributeConverter;
import jakarta.persistence.Converter;
import java.util.Arrays;

/**
 * Mirrors ENUM('Scheduled','Confirmed','Completed','Cancelled','No-Show').
 *
 * <p>The database spells one value "No-Show", which is not a legal Java
 * identifier, so {@code @Enumerated(EnumType.STRING)} cannot be used here - it
 * would persist "NO_SHOW" and the column would reject it. Each constant
 * therefore carries its exact database spelling and a converter does the
 * translation.
 */
public enum AppointmentStatus {

    SCHEDULED("Scheduled"),
    CONFIRMED("Confirmed"),
    COMPLETED("Completed"),
    CANCELLED("Cancelled"),
    NO_SHOW("No-Show");

    private final String dbValue;

    AppointmentStatus(String dbValue) {
        this.dbValue = dbValue;
    }

    public String dbValue() {
        return dbValue;
    }

    /** Accepts either the database spelling or the Java constant name. */
    public static AppointmentStatus from(String value) {
        if (value == null) {
            return null;
        }
        return Arrays.stream(values())
                .filter(s -> s.dbValue.equalsIgnoreCase(value) || s.name().equalsIgnoreCase(value))
                .findFirst()
                .orElseThrow(() -> new IllegalArgumentException("Unknown appointment status: " + value));
    }

    /** The two statuses for which active_slot_key is non-NULL, i.e. the slot is held. */
    public boolean isLive() {
        return this == SCHEDULED || this == CONFIRMED;
    }

    @Converter(autoApply = true)
    public static class JpaConverter implements AttributeConverter<AppointmentStatus, String> {

        @Override
        public String convertToDatabaseColumn(AppointmentStatus attribute) {
            return attribute == null ? null : attribute.dbValue();
        }

        @Override
        public AppointmentStatus convertToEntityAttribute(String dbData) {
            return from(dbData);
        }
    }
}
