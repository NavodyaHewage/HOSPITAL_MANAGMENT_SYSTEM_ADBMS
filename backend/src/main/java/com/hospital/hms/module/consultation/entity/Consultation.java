package com.hospital.hms.module.consultation.entity;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.LocalDate;
import java.time.LocalDateTime;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

@Entity
@Table(name = "consultations")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class Consultation {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "consultation_id")
    private Integer consultationId;

    /** UNIQUE in the schema: one appointment yields at most one consultation. */
    @Column(name = "appointment_id", nullable = false)
    private Integer appointmentId;

    @Column(name = "patient_id", nullable = false)
    private Integer patientId;

    @Column(name = "doctor_id", nullable = false)
    private Integer doctorId;

    @Column(name = "consultation_date", insertable = false, updatable = false)
    private LocalDateTime consultationDate;

    @Column(name = "chief_complaint")
    private String chiefComplaint;

    @Column(name = "diagnosis")
    private String diagnosis;

    @Column(name = "symptoms")
    private String symptoms;

    @Column(name = "treatment_plan")
    private String treatmentPlan;

    @Column(name = "notes")
    private String notes;

    @Column(name = "follow_up_date")
    private LocalDate followUpDate;

    @Column(name = "created_at", insertable = false, updatable = false)
    private LocalDateTime createdAt;
}
