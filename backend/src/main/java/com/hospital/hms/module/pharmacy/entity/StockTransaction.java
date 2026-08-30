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

/**
 * The stock ledger. quantity is ALWAYS positive - the direction comes from
 * transactionType, exactly as trg_stock_tx_ai_apply reads it:
 * Receive/Return add, Dispense/Adjustment subtract.
 */
@Entity
@Table(name = "stock_transactions")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class StockTransaction {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "transaction_id")
    private Integer transactionId;

    @Column(name = "batch_id", nullable = false)
    private Integer batchId;

    @Column(name = "medicine_id", nullable = false)
    private Integer medicineId;

    @Enumerated(EnumType.STRING)
    @Column(name = "transaction_type", nullable = false,
            columnDefinition = "enum('Receive','Dispense','Adjustment','Return')")
    private StockTransactionType transactionType;

    @Column(name = "quantity", nullable = false)
    private Integer quantity;

    @Column(name = "transaction_date", insertable = false, updatable = false)
    private LocalDateTime transactionDate;

    @Column(name = "performed_by", length = 100)
    private String performedBy;

    @Column(name = "reference_id")
    private Integer referenceId;

    @Column(name = "notes")
    private String notes;

    @Column(name = "created_at", insertable = false, updatable = false)
    private LocalDateTime createdAt;
}
