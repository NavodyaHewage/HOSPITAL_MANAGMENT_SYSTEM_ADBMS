package com.hospital.hms.module.laboratory.repository;

import com.hospital.hms.module.laboratory.entity.LabTest;
import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

@Repository
public interface LabTestRepository extends JpaRepository<LabTest, Integer> {

    List<LabTest> findAllByIsActiveTrueOrderByTestName();

    List<LabTest> findByTestCategoryAndIsActiveTrue(String testCategory);
}
