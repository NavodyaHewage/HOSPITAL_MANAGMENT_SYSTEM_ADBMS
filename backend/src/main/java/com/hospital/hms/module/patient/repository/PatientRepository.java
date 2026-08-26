package com.hospital.hms.module.patient.repository;

import com.hospital.hms.module.patient.entity.Patient;
import java.util.Optional;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

/** Read-side access. All writes go through PatientProcedureRepository. */
@Repository
public interface PatientRepository extends JpaRepository<Patient, Integer> {

    Optional<Patient> findByNationalId(String nationalId);

    @Query("""
            SELECT p FROM Patient p
            WHERE p.isActive = true
              AND (LOWER(CONCAT(p.firstName, ' ', p.lastName)) LIKE LOWER(CONCAT('%', :term, '%'))
                   OR p.phone LIKE CONCAT('%', :term, '%')
                   OR p.nationalId LIKE CONCAT('%', :term, '%'))
            """)
    Page<Patient> search(@Param("term") String term, Pageable pageable);
}
