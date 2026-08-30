package com.hospital.hms.module.pharmacy.repository;

import com.hospital.hms.module.pharmacy.entity.Medicine;
import java.util.List;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

@Repository
public interface MedicineRepository extends JpaRepository<Medicine, Integer> {

    List<Medicine> findAllByIsActiveTrueOrderByMedicineName();

    @Query("""
            SELECT m FROM Medicine m
            WHERE m.isActive = true
              AND (:term IS NULL OR :term = ''
                   OR LOWER(m.medicineName) LIKE LOWER(CONCAT('%', :term, '%'))
                   OR LOWER(m.genericName)  LIKE LOWER(CONCAT('%', :term, '%')))
              AND (:category IS NULL OR m.category = :category)
            """)
    Page<Medicine> search(@Param("term") String term,
                          @Param("category") String category,
                          Pageable pageable);
}
