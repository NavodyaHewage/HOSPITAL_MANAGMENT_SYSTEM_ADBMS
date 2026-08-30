package com.hospital.hms.module.billing.repository;

import com.hospital.hms.module.billing.entity.Service;
import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

@Repository
public interface ServiceRepository extends JpaRepository<Service, Integer> {

    List<Service> findAllByIsActiveTrueOrderByServiceName();

    List<Service> findByServiceCategoryAndIsActiveTrue(String serviceCategory);
}
