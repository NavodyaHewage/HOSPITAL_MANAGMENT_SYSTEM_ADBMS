package com.hospital.hms.module.report.repository;

import com.hospital.hms.module.report.entity.MonthlyRevenueSummary;
import com.hospital.hms.module.report.entity.MonthlyRevenueSummaryId;
import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

@Repository
public interface MonthlyRevenueSummaryRepository
        extends JpaRepository<MonthlyRevenueSummary, MonthlyRevenueSummaryId> {

    List<MonthlyRevenueSummary> findByYmKeyOrderByDepartmentId(String ymKey);
}
