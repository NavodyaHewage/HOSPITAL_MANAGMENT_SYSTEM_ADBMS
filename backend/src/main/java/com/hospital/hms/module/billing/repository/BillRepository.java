package com.hospital.hms.module.billing.repository;

import com.hospital.hms.module.billing.entity.Bill;
import com.hospital.hms.module.billing.entity.BillStatus;
import java.util.List;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

@Repository
public interface BillRepository extends JpaRepository<Bill, Integer> {

    /** Uses idx_bills_patient_status. */
    Page<Bill> findByPatientIdOrderByBillDateDesc(Integer patientId, Pageable pageable);

    Page<Bill> findByStatusInOrderByBillDateDesc(List<BillStatus> statuses, Pageable pageable);

    List<Bill> findByAppointmentId(Integer appointmentId);
}
