package com.hospital.hms.module.report.service.impl;

import com.hospital.hms.module.department.entity.Department;
import com.hospital.hms.module.department.repository.DepartmentRepository;
import com.hospital.hms.module.report.dto.response.MonthlyRevenueResponse;
import com.hospital.hms.module.report.entity.MonthlyRevenueSummary;
import com.hospital.hms.module.report.repository.MonthlyRevenueSummaryRepository;
import com.hospital.hms.module.report.repository.procedure.ReportProcedureRepository;
import com.hospital.hms.module.report.service.ReportService;
import java.math.BigDecimal;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class ReportServiceImpl implements ReportService {

    private final MonthlyRevenueSummaryRepository summaryRepository;
    private final ReportProcedureRepository procedureRepository;
    private final DepartmentRepository departmentRepository;

    public ReportServiceImpl(MonthlyRevenueSummaryRepository summaryRepository,
                             ReportProcedureRepository procedureRepository,
                             DepartmentRepository departmentRepository) {
        this.summaryRepository = summaryRepository;
        this.procedureRepository = procedureRepository;
        this.departmentRepository = departmentRepository;
    }

    /** Reads the pre-aggregated table - a PK lookup, not a live aggregation. */
    @Override
    @Transactional(readOnly = true)
    public List<MonthlyRevenueResponse> monthlyRevenue(String ymKey) {
        return hydrate(summaryRepository.findByYmKeyOrderByDepartmentId(ymKey));
    }

    /**
     * Rebuilds the month, then reads it back. No @Transactional - the procedure
     * runs its own DELETE + INSERT transaction.
     */
    @Override
    public List<MonthlyRevenueResponse> refreshAndGet(String ymKey) {
        procedureRepository.refreshMonth(ymKey);
        return monthlyRevenue(ymKey);
    }

    private List<MonthlyRevenueResponse> hydrate(List<MonthlyRevenueSummary> rows) {
        Map<Integer, String> departments = departmentRepository
                .findAllById(rows.stream().map(MonthlyRevenueSummary::getDepartmentId).toList())
                .stream().collect(Collectors.toMap(Department::getDepartmentId,
                        Department::getDepartmentName, (a, b) -> a));

        return rows.stream()
                .map(r -> new MonthlyRevenueResponse(
                        r.getYmKey(),
                        r.getDepartmentId(),
                        departments.get(r.getDepartmentId()),
                        r.getBillCount(),
                        r.getTotalBilled(),
                        r.getTotalPaid(),
                        subtract(r.getTotalBilled(), r.getTotalPaid()),
                        r.getRefreshedAt()))
                .toList();
    }

    private BigDecimal subtract(BigDecimal billed, BigDecimal paid) {
        BigDecimal left = billed == null ? BigDecimal.ZERO : billed;
        BigDecimal right = paid == null ? BigDecimal.ZERO : paid;
        return left.subtract(right);
    }
}
