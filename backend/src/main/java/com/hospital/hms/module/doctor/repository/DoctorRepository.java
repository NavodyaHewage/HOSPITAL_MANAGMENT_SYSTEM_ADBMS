package com.hospital.hms.module.doctor.repository;

import com.hospital.hms.module.doctor.entity.Doctor;
import java.util.List;
import java.util.Optional;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

@Repository
public interface DoctorRepository extends JpaRepository<Doctor, Integer> {

    /** Hits idx_doctors_department_active. */
    List<Doctor> findByDepartmentIdAndIsActiveTrue(Integer departmentId);

    Optional<Doctor> findByLicenseNumber(String licenseNumber);

    long countByDepartmentIdAndIsActiveTrue(Integer departmentId);

    @Query("""
            SELECT d FROM Doctor d
            WHERE d.isActive = true
              AND (:departmentId IS NULL OR d.departmentId = :departmentId)
              AND (:term IS NULL OR :term = ''
                   OR LOWER(CONCAT(d.firstName, ' ', d.lastName)) LIKE LOWER(CONCAT('%', :term, '%'))
                   OR LOWER(d.specialization) LIKE LOWER(CONCAT('%', :term, '%')))
            """)
    Page<Doctor> search(@Param("term") String term,
                        @Param("departmentId") Integer departmentId,
                        Pageable pageable);
}
