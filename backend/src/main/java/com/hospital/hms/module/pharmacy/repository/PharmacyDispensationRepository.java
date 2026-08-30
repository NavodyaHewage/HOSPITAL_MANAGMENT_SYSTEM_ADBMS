package com.hospital.hms.module.pharmacy.repository;

import com.hospital.hms.module.pharmacy.entity.PharmacyDispensation;
import java.util.List;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

@Repository
public interface PharmacyDispensationRepository extends JpaRepository<PharmacyDispensation, Integer> {

    List<PharmacyDispensation> findByPrescriptionId(Integer prescriptionId);

    Page<PharmacyDispensation> findByPatientIdOrderByDispensedDateDesc(Integer patientId, Pageable pageable);
}
