package com.hospital.hms.module.laboratory.repository.view;

import com.hospital.hms.module.laboratory.entity.LabOrder;
import java.util.List;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.Repository;
import org.springframework.data.repository.query.Param;

public interface LabViewRepository extends Repository<LabOrder, Integer> {

    /**
     * The lab worklist. Ordered Stat -> Urgent -> Routine, then oldest first:
     * FIELD() gives the priority enum a clinical ordering rather than the
     * alphabetical one a plain ORDER BY would produce.
     */
    @Query(value = """
            SELECT order_id, patient_id, doctor_id, appointment_id, test_name,
                   test_category, priority, order_date, status, hours_waiting
            FROM vw_pending_lab_work
            ORDER BY FIELD(priority, 'Stat', 'Urgent', 'Routine'), order_date
            LIMIT :limit
            """, nativeQuery = true)
    List<PendingLabWorkView> findPendingWork(@Param("limit") int limit);
}
