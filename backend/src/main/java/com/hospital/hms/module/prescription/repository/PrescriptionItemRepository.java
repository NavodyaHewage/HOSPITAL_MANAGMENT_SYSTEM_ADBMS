package com.hospital.hms.module.prescription.repository;

import com.hospital.hms.module.prescription.entity.PrescriptionItem;
import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

@Repository
public interface PrescriptionItemRepository extends JpaRepository<PrescriptionItem, Integer> {

    List<PrescriptionItem> findByPrescriptionId(Integer prescriptionId);

    List<PrescriptionItem> findByPrescriptionIdIn(List<Integer> prescriptionIds);
}
