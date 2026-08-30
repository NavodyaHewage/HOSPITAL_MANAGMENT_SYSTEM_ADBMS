package com.hospital.hms.module.billing.entity;

import jakarta.persistence.Column;
import jakarta.persistence.Convert;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.math.BigDecimal;
import java.time.LocalDateTime;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

/**
 * The payment ledger. Inserting a row here is the ONLY way a bill's
 * paid_amount, balance_amount and status change - trg_payments_ai_apply derives
 * all three. trg_payments_bi_validate rejects the row first if it would
 * overpay the bill or if the bill is cancelled.
 */
@Entity
@Table(name = "payments")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class Payment {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "payment_id")
    private Integer paymentId;

    @Column(name = "bill_id", nullable = false)
    private Integer billId;

    @Column(name = "payment_date", insertable = false, updatable = false)
    private LocalDateTime paymentDate;

    @Column(name = "amount", nullable = false, precision = 10, scale = 2)
    private BigDecimal amount;

    @Convert(converter = PaymentMethod.JpaConverter.class)
    @Column(name = "payment_method", nullable = false,
            columnDefinition = "enum('Cash','Card','Insurance','Bank Transfer')")
    private PaymentMethod paymentMethod;

    @Column(name = "reference_number", length = 50)
    private String referenceNumber;

    @Column(name = "received_by", length = 100)
    private String receivedBy;

    @Column(name = "notes")
    private String notes;

    @Column(name = "created_at", insertable = false, updatable = false)
    private LocalDateTime createdAt;
}
