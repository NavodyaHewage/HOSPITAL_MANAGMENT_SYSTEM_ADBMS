package com.hospital.hms.module.report.entity;

import java.io.Serializable;
import java.util.Objects;
import lombok.AllArgsConstructor;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

/** Composite key of monthly_revenue_summary: (ym_key, department_id). */
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
public class MonthlyRevenueSummaryId implements Serializable {

    private String ymKey;
    private Integer departmentId;

    @Override
    public boolean equals(Object other) {
        if (this == other) {
            return true;
        }
        if (!(other instanceof MonthlyRevenueSummaryId that)) {
            return false;
        }
        return Objects.equals(ymKey, that.ymKey)
                && Objects.equals(departmentId, that.departmentId);
    }

    @Override
    public int hashCode() {
        return Objects.hash(ymKey, departmentId);
    }
}
