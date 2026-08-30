package com.hospital.hms.module.report.service;

import com.hospital.hms.module.report.dto.response.MonthlyRevenueResponse;
import java.util.List;

public interface ReportService {

    List<MonthlyRevenueResponse> monthlyRevenue(String ymKey);

    List<MonthlyRevenueResponse> refreshAndGet(String ymKey);
}
