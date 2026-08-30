package com.hospital.hms.module.laboratory.entity;

import jakarta.persistence.Column;
import jakarta.persistence.Convert;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.LocalDateTime;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

@Entity
@Table(name = "lab_orders")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class LabOrder {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "order_id")
    private Integer orderId;

    @Column(name = "appointment_id", nullable = false)
    private Integer appointmentId;

    @Column(name = "patient_id", nullable = false)
    private Integer patientId;

    @Column(name = "doctor_id", nullable = false)
    private Integer doctorId;

    @Column(name = "test_id", nullable = false)
    private Integer testId;

    @Column(name = "order_date", insertable = false, updatable = false)
    private LocalDateTime orderDate;

    @Enumerated(EnumType.STRING)
    @Column(name = "priority", nullable = false,
            columnDefinition = "enum('Routine','Urgent','Stat')")
    private LabPriority priority;

    /**
     * OWNED BY trg_lab_result_ai_close once a result is entered - recording a
     * result flips the order to Completed. Writing this from Java for a
     * completed order would fight the trigger.
     */
    @Convert(converter = LabOrderStatus.JpaConverter.class)
    @Column(name = "status", nullable = false,
            columnDefinition = "enum('Pending','In-Progress','Completed','Cancelled')")
    private LabOrderStatus status;

    @Column(name = "notes")
    private String notes;

    @Column(name = "created_at", insertable = false, updatable = false)
    private LocalDateTime createdAt;
}
