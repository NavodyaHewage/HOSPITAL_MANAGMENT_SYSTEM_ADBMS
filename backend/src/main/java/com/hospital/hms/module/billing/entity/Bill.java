package com.hospital.hms.module.billing.entity;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import jakarta.persistence.Version;
import java.math.BigDecimal;
import java.time.LocalDateTime;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

@Entity
@Table(name = "bills")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class Bill {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "bill_id")
    private Integer billId;

    @Column(name = "patient_id", nullable = false)
    private Integer patientId;

    @Column(name = "appointment_id")
    private Integer appointmentId;

    @Column(name = "bill_date", insertable = false, updatable = false)
    private LocalDateTime billDate;

    @Column(name = "subtotal", nullable = false, precision = 10, scale = 2)
    private BigDecimal subtotal;

    @Column(name = "discount", nullable = false, precision = 10, scale = 2)
    private BigDecimal discount;

    @Column(name = "tax", nullable = false, precision = 10, scale = 2)
    private BigDecimal tax;

    @Column(name = "total_amount", nullable = false, precision = 10, scale = 2)
    private BigDecimal totalAmount;

    /**
     * OWNED BY trg_payments_ai_apply. These three are derived from the payments
     * table by the trigger, so they are mapped read-only here - a stray save()
     * must not be able to claim a bill was paid when no payment row exists.
     */
    @Column(name = "paid_amount", nullable = false, precision = 10, scale = 2,
            insertable = false, updatable = false)
    private BigDecimal paidAmount;

    @Column(name = "balance_amount", nullable = false, precision = 10, scale = 2,
            insertable = false, updatable = false)
    private BigDecimal balanceAmount;

    @Enumerated(EnumType.STRING)
    @Column(name = "status", nullable = false, insertable = false, updatable = false,
            columnDefinition = "enum('Pending','Partial','Paid','Cancelled')")
    private BillStatus status;

    /**
     * Optimistic-locking counter. @Version makes Hibernate check-and-bump it on
     * every update, so two concurrent edits to the same bill cannot silently
     * overwrite one another - the loser gets an OptimisticLockException.
     */
    @Version
    @Column(name = "row_version", nullable = false)
    private Integer rowVersion;

    @Column(name = "created_at", insertable = false, updatable = false)
    private LocalDateTime createdAt;

    @Column(name = "updated_at", insertable = false, updatable = false)
    private LocalDateTime updatedAt;
}
