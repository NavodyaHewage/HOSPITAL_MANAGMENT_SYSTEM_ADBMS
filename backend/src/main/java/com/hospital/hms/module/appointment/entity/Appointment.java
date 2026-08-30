package com.hospital.hms.module.appointment.entity;

import jakarta.persistence.Column;
import jakarta.persistence.Convert;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.LocalTime;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

@Entity
@Table(name = "appointments")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class Appointment {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "appointment_id")
    private Integer appointmentId;

    @Column(name = "patient_id", nullable = false)
    private Integer patientId;

    @Column(name = "doctor_id", nullable = false)
    private Integer doctorId;

    @Column(name = "appointment_date", nullable = false)
    private LocalDate appointmentDate;

    @Column(name = "appointment_time", nullable = false)
    private LocalTime appointmentTime;

    @Convert(converter = AppointmentStatus.JpaConverter.class)
    @Column(name = "status", nullable = false,
            columnDefinition = "enum('Scheduled','Confirmed','Completed','Cancelled','No-Show')")
    private AppointmentStatus status;

    @Column(name = "reason")
    private String reason;

    @Column(name = "notes")
    private String notes;

    /**
     * STORED GENERATED column - the database computes it and a UNIQUE index on
     * it is what makes a double booking impossible. Never written from Java.
     */
    @Column(name = "active_slot_key", insertable = false, updatable = false)
    private String activeSlotKey;

    @Column(name = "created_at", insertable = false, updatable = false)
    private LocalDateTime createdAt;

    @Column(name = "updated_at", insertable = false, updatable = false)
    private LocalDateTime updatedAt;
}
