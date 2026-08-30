package com.hospital.hms.module.report.entity;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.IdClass;
import jakarta.persistence.Table;
import java.math.BigDecimal;
import java.time.LocalDateTime;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

/**
 * Pre-aggregated month-end revenue - the materialised-view pattern.
 *
 * <p>Reading this is a primary-key lookup instead of a four-table join over
 * 20,000 bills. The trade-off is staleness: it is only as fresh as the last
 * sp_refresh_monthly_revenue call, which is correct for a month-end report and
 * wrong for a live balance. Live balances come from the bills table.
 */
@Entity
@Table(name = "monthly_revenue_summary")
@IdClass(MonthlyRevenueSummaryId.class)
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class MonthlyRevenueSummary {

    /** CHAR(7), not VARCHAR - e.g. '2026-08'. Fixed width, so the column is too. */
    @Id
    @Column(name = "ym_key", nullable = false, length = 7, columnDefinition = "char(7)")
    private String ymKey;

    @Id
    @Column(name = "department_id", nullable = false)
    private Integer departmentId;

    @Column(name = "bill_count", nullable = false)
    private Integer billCount;

    @Column(name = "total_billed", nullable = false, precision = 14, scale = 2)
    private BigDecimal totalBilled;

    @Column(name = "total_paid", nullable = false, precision = 14, scale = 2)
    private BigDecimal totalPaid;

    @Column(name = "refreshed_at", insertable = false, updatable = false)
    private LocalDateTime refreshedAt;
}
