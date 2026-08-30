package com.hospital.hms.module.pharmacy.entity;

import jakarta.persistence.Column;
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
@Table(name = "pharmacy_dispensations")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class PharmacyDispensation {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "dispensation_id")
    private Integer dispensationId;

    @Column(name = "prescription_id", nullable = false)
    private Integer prescriptionId;

    @Column(name = "patient_id", nullable = false)
    private Integer patientId;

    @Column(name = "dispensed_date", insertable = false, updatable = false)
    private LocalDateTime dispensedDate;

    @Column(name = "dispensed_by", length = 100)
    private String dispensedBy;

    @Column(name = "total_items", nullable = false)
    private Integer totalItems;

    @Enumerated(EnumType.STRING)
    @Column(name = "status", nullable = false,
            columnDefinition = "enum('Completed','Partial')")
    private DispensationStatus status;

    @Column(name = "notes")
    private String notes;

    @Column(name = "created_at", insertable = false, updatable = false)
    private LocalDateTime createdAt;
}
