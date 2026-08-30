package com.hospital.hms.module.laboratory.repository;

import com.hospital.hms.module.laboratory.entity.LabResult;
import java.util.List;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

@Repository
public interface LabResultRepository extends JpaRepository<LabResult, Integer> {

    Optional<LabResult> findByOrderId(Integer orderId);

    boolean existsByOrderId(Integer orderId);

    List<LabResult> findByOrderIdIn(List<Integer> orderIds);
}
