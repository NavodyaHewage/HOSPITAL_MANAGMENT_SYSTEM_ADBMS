package com.hospital.hms.module.laboratory.repository;

import com.hospital.hms.module.laboratory.entity.LabOrder;
import com.hospital.hms.module.laboratory.entity.LabOrderStatus;
import java.util.List;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

@Repository
public interface LabOrderRepository extends JpaRepository<LabOrder, Integer> {

    /** Uses idx_lab_orders_appointment_status. */
    List<LabOrder> findByAppointmentId(Integer appointmentId);

    Page<LabOrder> findByPatientIdOrderByOrderDateDesc(Integer patientId, Pageable pageable);

    /** Uses idx_lab_orders_status_priority. */
    Page<LabOrder> findByStatusOrderByPriorityAscOrderDateAsc(LabOrderStatus status, Pageable pageable);
}
