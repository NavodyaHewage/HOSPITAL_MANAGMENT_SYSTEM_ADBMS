package com.hospital.hms.module.laboratory.entity;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
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
@Table(name = "lab_results")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class LabResult {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "result_id")
    private Integer resultId;

    /**
     * UNIQUE in the schema. Two technicians typing a result for the same order
     * is a patient-safety problem, so the constraint makes it impossible rather
     * than unlikely - the second INSERT fails with a duplicate key.
     */
    @Column(name = "order_id", nullable = false)
    private Integer orderId;

    @Column(name = "result_value", length = 255)
    private String resultValue;

    @Column(name = "result_date", insertable = false, updatable = false)
    private LocalDateTime resultDate;

    @Column(name = "performed_by", length = 100)
    private String performedBy;

    @Column(name = "remarks")
    private String remarks;

    @Column(name = "is_abnormal", nullable = false)
    private Boolean isAbnormal;

    @Column(name = "created_at", insertable = false, updatable = false)
    private LocalDateTime createdAt;
}
