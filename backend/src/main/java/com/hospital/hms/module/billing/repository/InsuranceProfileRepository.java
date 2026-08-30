package com.hospital.hms.module.billing.repository;

import com.hospital.hms.module.billing.entity.InsuranceProfile;
import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

@Repository
public interface InsuranceProfileRepository extends JpaRepository<InsuranceProfile, Integer> {

    List<InsuranceProfile> findByPatientId(Integer patientId);

    /**
     * Only policies that are active AND inside their validity window - the same
     * test fn_calculate_insurance_covered_amount applies. Checking is_active
     * alone would happily apply an expired policy.
     */
    @Query("""
            SELECT i FROM InsuranceProfile i
            WHERE i.patientId = :patientId
              AND i.isActive = true
              AND i.validFrom <= CURRENT_DATE
              AND (i.validTo IS NULL OR i.validTo >= CURRENT_DATE)
            ORDER BY i.coveragePercentage DESC
            """)
    List<InsuranceProfile> findValidPolicies(@Param("patientId") Integer patientId);
}
