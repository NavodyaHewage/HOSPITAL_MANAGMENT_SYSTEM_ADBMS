-- ============================================================================
-- ============================================================================

-- ----------------------------------------------------------------------------
-- MEMBER 1 — VIEWS
-- ----------------------------------------------------------------------------
CREATE OR REPLACE VIEW vw_upcoming_appointments AS
SELECT a.appointment_id,
       a.patient_id,
       CONCAT(p.first_name,' ',p.last_name) AS patient_name,
       a.doctor_id,
       CONCAT(d.first_name,' ',d.last_name) AS doctor_name,
       dep.department_name,
       a.appointment_date,
       a.appointment_time,
       a.status
FROM appointments a
JOIN patients    p   ON p.patient_id   = a.patient_id
JOIN doctors     d   ON d.doctor_id    = a.doctor_id
JOIN departments dep ON dep.department_id = d.department_id
WHERE a.appointment_date >= CURDATE()
  AND a.status IN ('Scheduled','Confirmed');

CREATE OR REPLACE VIEW vw_doctor_daily_schedule AS
SELECT d.doctor_id,
       CONCAT(d.first_name,' ',d.last_name) AS doctor_name,
       a.appointment_date,
       a.appointment_time,
       a.status,
       a.patient_id,
       CONCAT(p.first_name,' ',p.last_name) AS patient_name,
       a.reason
FROM doctors d
JOIN appointments a ON a.doctor_id  = d.doctor_id
JOIN patients     p ON p.patient_id = a.patient_id;

CREATE OR REPLACE VIEW vw_patient_appointment_history AS
SELECT p.patient_id,
       CONCAT(p.first_name,' ',p.last_name) AS patient_name,
       a.appointment_id,
       a.appointment_date,
       a.appointment_time,
       CONCAT(d.first_name,' ',d.last_name) AS doctor_name,
       a.status,
       a.reason
FROM patients p
JOIN appointments a ON a.patient_id = p.patient_id
JOIN doctors     d ON d.doctor_id  = a.doctor_id;

-- ----------------------------------------------------------------------------
-- MEMBER 2 — VIEWS
-- ----------------------------------------------------------------------------
CREATE OR REPLACE VIEW vw_patient_clinical_history AS
SELECT c.patient_id,
       c.consultation_id,
       c.appointment_id,
       c.consultation_date,
       c.chief_complaint,
       c.diagnosis,
       c.follow_up_date,
       c.doctor_id,
       CONCAT(d.first_name,' ',d.last_name) AS doctor_name
FROM consultations c
JOIN doctors d ON d.doctor_id = c.doctor_id;

CREATE OR REPLACE VIEW vw_active_prescriptions AS
SELECT pr.prescription_id,
       pr.patient_id,
       pr.doctor_id,
       pr.prescription_date,
       pi.item_id,
       pi.medicine_id,
       m.medicine_name,
       pi.dosage,
       pi.frequency,
       pi.duration_days,
       pi.quantity
FROM prescriptions      pr
JOIN prescription_items pi ON pi.prescription_id = pr.prescription_id
JOIN medicines          m  ON m.medicine_id      = pi.medicine_id
WHERE pr.status = 'Active';

CREATE OR REPLACE VIEW vw_pending_lab_work AS
SELECT lo.order_id,
       lo.patient_id,
       lo.doctor_id,
       lo.appointment_id,
       lt.test_name,
       lt.test_category,
       lo.priority,
       lo.order_date,
       lo.status,
       TIMESTAMPDIFF(HOUR, lo.order_date, NOW()) AS hours_waiting
FROM lab_orders lo
JOIN lab_tests  lt ON lt.test_id = lo.test_id
WHERE lo.status IN ('Pending','In-Progress');

-- ----------------------------------------------------------------------------
-- MEMBER 3 — VIEWS
-- ----------------------------------------------------------------------------
CREATE OR REPLACE VIEW vw_patient_billing_summary AS
SELECT b.patient_id,
       COUNT(*)                AS total_bills,
       SUM(b.total_amount)     AS total_billed,
       SUM(b.paid_amount)      AS total_paid,
       SUM(b.balance_amount)   AS total_balance,
       MAX(b.bill_date)        AS last_bill_date
FROM bills b
WHERE b.status <> 'Cancelled'
GROUP BY b.patient_id;

CREATE OR REPLACE VIEW vw_outstanding_bills AS
SELECT b.bill_id,
       b.patient_id,
       CONCAT(p.first_name,' ',p.last_name) AS patient_name,
       p.phone,
       b.bill_date,
       b.total_amount,
       b.paid_amount,
       b.balance_amount,
       b.status,
       DATEDIFF(CURDATE(), DATE(b.bill_date)) AS days_outstanding
FROM bills b
JOIN patients p ON p.patient_id = b.patient_id
WHERE b.status IN ('Pending','Partial');

CREATE OR REPLACE VIEW vw_payment_history AS
SELECT pay.payment_id,
       pay.bill_id,
       b.patient_id,
       pay.payment_date,
       pay.amount,
       pay.payment_method,
       pay.reference_number,
       pay.received_by
FROM payments pay
JOIN bills b ON b.bill_id = pay.bill_id;

-- ----------------------------------------------------------------------------
-- MEMBER 4 — VIEWS
-- ----------------------------------------------------------------------------
CREATE OR REPLACE VIEW vw_current_medicine_stock AS
SELECT m.medicine_id,
       m.medicine_name,
       m.category,
       m.reorder_level,
       COALESCE(SUM(ib.quantity_available), 0) AS total_available,
       CASE WHEN COALESCE(SUM(ib.quantity_available), 0) <= m.reorder_level
            THEN 'REORDER' ELSE 'OK' END       AS stock_status
FROM medicines m
LEFT JOIN inventory_batches ib
       ON ib.medicine_id = m.medicine_id
      AND ib.expiry_date >= CURDATE()
WHERE m.is_active = TRUE
GROUP BY m.medicine_id, m.medicine_name, m.category, m.reorder_level;

CREATE OR REPLACE VIEW vw_expiring_batches AS
SELECT ib.batch_id,
       ib.medicine_id,
       m.medicine_name,
       ib.batch_number,
       ib.quantity_available,
       ib.expiry_date,
       DATEDIFF(ib.expiry_date, CURDATE()) AS days_to_expiry,
       CASE WHEN ib.expiry_date < CURDATE() THEN 'EXPIRED'
            WHEN ib.expiry_date <= CURDATE() + INTERVAL 30 DAY THEN 'CRITICAL'
            ELSE 'WATCH' END               AS expiry_status
FROM inventory_batches ib
JOIN medicines m ON m.medicine_id = ib.medicine_id
WHERE ib.quantity_available > 0
  AND ib.expiry_date <= CURDATE() + INTERVAL 90 DAY;

CREATE OR REPLACE VIEW vw_dispensing_history AS
SELECT pd.dispensation_id,
       pd.patient_id,
       pd.prescription_id,
       pd.dispensed_date,
       pd.dispensed_by,
       pd.total_items,
       pd.status,
       pr.doctor_id
FROM pharmacy_dispensations pd
JOIN prescriptions pr ON pr.prescription_id = pd.prescription_id;

-- ----------------------------------------------------------------------------
-- MEMBER 5 — VIEWS
-- ----------------------------------------------------------------------------
CREATE OR REPLACE VIEW vw_user_role_summary AS
SELECT u.user_id,
       u.username,
       u.full_name,
       u.is_active,
       COUNT(r.role_id)                        AS role_count,
       GROUP_CONCAT(r.role_name ORDER BY r.role_name SEPARATOR ', ') AS roles
FROM users u
LEFT JOIN user_roles ur ON ur.user_id = u.user_id
LEFT JOIN roles      r  ON r.role_id  = ur.role_id
GROUP BY u.user_id, u.username, u.full_name, u.is_active;

CREATE OR REPLACE VIEW vw_permission_matrix AS
SELECT r.role_id,
       r.role_name,
       p.permission_id,
       p.permission_name,
       p.module
FROM roles r
JOIN role_permissions rp ON rp.role_id       = r.role_id
JOIN permissions      p  ON p.permission_id  = rp.permission_id;

-- No LIMIT inside the view: a LIMIT forces the TEMPTABLE algorithm and stops
-- predicate push-down. Callers apply their own ORDER BY / LIMIT.
CREATE OR REPLACE VIEW vw_recent_audit_activity AS
SELECT al.log_id,
       al.user_id,
       u.username,
       al.entity_name,
       al.entity_id,
       al.action,
       al.ip_address,
       al.created_at
FROM audit_logs al
LEFT JOIN users u ON u.user_id = al.user_id
WHERE al.created_at >= NOW() - INTERVAL 30 DAY;

-- ============================================================================
-- VERIFY
-- ============================================================================
SELECT ROUTINE_NAME, ROUTINE_TYPE, IS_DETERMINISTIC, SQL_DATA_ACCESS
FROM information_schema.ROUTINES
WHERE ROUTINE_SCHEMA = 'hospital_management'
ORDER BY ROUTINE_TYPE, ROUTINE_NAME;

SELECT TABLE_NAME AS view_name
FROM information_schema.VIEWS
WHERE TABLE_SCHEMA = 'hospital_management'
ORDER BY TABLE_NAME;

-- Quick smoke test
SELECT fn_calculate_patient_age(1)                       AS age_of_patient_1,
       fn_count_patient_appointments(1, NULL)            AS all_appts_patient_1,
       fn_calculate_bill_balance(1)                      AS balance_bill_1,
       fn_calculate_available_stock(1)                   AS stock_medicine_1,
       fn_check_user_permission(1, 'PATIENT_READ')       AS user1_can_read_patients;

-- END OF FILE 03


-- ############################################################################
-- ##  STAGE 4  --  04_procedures.sql
