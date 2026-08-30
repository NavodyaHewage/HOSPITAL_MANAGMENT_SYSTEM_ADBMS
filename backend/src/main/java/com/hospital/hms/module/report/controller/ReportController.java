package com.hospital.hms.module.report.controller;

import com.hospital.hms.common.dto.ApiResponse;
import com.hospital.hms.module.report.dto.response.MonthlyRevenueResponse;
import com.hospital.hms.module.report.service.ReportService;
import jakarta.validation.constraints.Pattern;
import java.util.List;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/reports")
@Validated
public class ReportController {

    private static final String YM_PATTERN = "\\d{4}-\\d{2}";

    private final ReportService reportService;

    public ReportController(ReportService reportService) {
        this.reportService = reportService;
    }

    /**
     * Reads the pre-aggregated summary. Fast, but only as fresh as the last
     * refresh - call POST /reports/monthly-revenue/refresh to rebuild it.
     */
    @GetMapping("/monthly-revenue")
    @PreAuthorize("hasAuthority(T(com.hospital.hms.security.rbac.Permissions).PAYMENT_RECORD)")
    public ApiResponse<List<MonthlyRevenueResponse>> monthlyRevenue(
            @RequestParam @Pattern(regexp = YM_PATTERN, message = "must look like 2026-08") String month) {
        return ApiResponse.ok(reportService.monthlyRevenue(month));
    }

    @PostMapping("/monthly-revenue/refresh")
    @PreAuthorize("hasAuthority(T(com.hospital.hms.security.rbac.Permissions).USER_MANAGE)")
    public ApiResponse<List<MonthlyRevenueResponse>> refresh(
            @RequestParam @Pattern(regexp = YM_PATTERN, message = "must look like 2026-08") String month) {
        return ApiResponse.ok("Summary refreshed", reportService.refreshAndGet(month));
    }
}
