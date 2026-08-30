package com.hospital.hms.module.pharmacy.entity;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

@Entity
@Table(name = "inventory_batches")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class InventoryBatch {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "batch_id")
    private Integer batchId;

    @Column(name = "medicine_id", nullable = false)
    private Integer medicineId;

    @Column(name = "batch_number", nullable = false, length = 50)
    private String batchNumber;

    @Column(name = "quantity_received", nullable = false)
    private Integer quantityReceived;

    /**
     * OWNED BY trg_stock_tx_ai_apply. Never write this from Java - every change
     * must arrive as a stock_transactions row so the batch and its ledger agree.
     * Mapped read-only so an accidental save() cannot corrupt it.
     */
    @Column(name = "quantity_available", nullable = false, insertable = false, updatable = false)
    private Integer quantityAvailable;

    @Column(name = "manufacture_date")
    private LocalDate manufactureDate;

    @Column(name = "expiry_date", nullable = false)
    private LocalDate expiryDate;

    @Column(name = "supplier_name", length = 100)
    private String supplierName;

    @Column(name = "purchase_price", precision = 10, scale = 2)
    private BigDecimal purchasePrice;

    @Column(name = "received_date", insertable = false, updatable = false)
    private LocalDate receivedDate;

    @Column(name = "created_at", insertable = false, updatable = false)
    private LocalDateTime createdAt;
}
