package com.hospital.hms.module.report.dto.response;

import java.math.BigDecimal;
import java.time.LocalDateTime;

public record MonthlyRevenueResponse(
        String ymKey,
        Integer departmentId,
        String departmentName,
        Integer billCount,
        BigDecimal totalBilled,
        BigDecimal totalPaid,
        BigDecimal totalOutstanding,
        LocalDateTime refreshedAt) {
}
