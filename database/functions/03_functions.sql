-- ############################################################################

-- ============================================================================
--  FILE 03 of 08 : FUNCTIONS (15) + VIEWS (15)   — 3 of each per member
-- ============================================================================
--  TWO CORRECTNESS FIXES YOU SHOULD BE READY TO DEFEND:
--
--  1) CHARACTERISTIC = READS SQL DATA, not DETERMINISTIC.
--     A function is DETERMINISTIC only if the same input ALWAYS gives the same
--     output. Every function here reads tables, so its result changes as data
--     changes -> declaring DETERMINISTIC is factually wrong and lets MySQL
--     cache/optimise it incorrectly (and is unsafe for replication).
--
--  2) NO "ORDER BY" INSIDE A VIEW.
--     MySQL is allowed to discard a view's ORDER BY when the view is merged
--     into the outer query, so it is a false guarantee AND it blocks the
--     MERGE algorithm (forcing a temp table = slower). Sorting belongs in the
--     query that selects FROM the view.
-- ============================================================================

USE hospital_management;

DELIMITER $$

-- ============================================================================
-- MEMBER 1 — FUNCTIONS
-- ============================================================================

DROP FUNCTION IF EXISTS fn_calculate_patient_age$$
CREATE FUNCTION fn_calculate_patient_age(p_patient_id INT)
RETURNS INT
READS SQL DATA
BEGIN
    DECLARE v_age INT DEFAULT NULL;
    SELECT TIMESTAMPDIFF(YEAR, date_of_birth, CURDATE())
      INTO v_age
      FROM patients
     WHERE patient_id = p_patient_id;
    RETURN v_age;              -- NULL if the patient does not exist
END$$

DROP FUNCTION IF EXISTS fn_count_patient_appointments$$
CREATE FUNCTION fn_count_patient_appointments(p_patient_id INT, p_status VARCHAR(20))
RETURNS INT
READS SQL DATA
BEGIN
    DECLARE v_count INT DEFAULT 0;
    -- p_status NULL  -> count all statuses. Uses idx_appointments_patient_status.
    SELECT COUNT(*) INTO v_count
      FROM appointments
     WHERE patient_id = p_patient_id
       AND (p_status IS NULL OR status = p_status);
    RETURN v_count;
END$$

-- FIX vs original: also verifies the doctor exists and is active. The original
-- returned TRUE for a deleted/inactive doctor.
-- NOTE FOR L12-L13: this function is only a CONVENIENCE CHECK. It is not a
-- concurrency guarantee - between the check and the INSERT another session can
-- grab the slot. The real guarantee is UNIQUE(active_slot_key) + FOR UPDATE.
DROP FUNCTION IF EXISTS fn_check_doctor_availability$$
CREATE FUNCTION fn_check_doctor_availability(p_doctor_id INT, p_date DATE, p_time TIME)
RETURNS BOOLEAN
READS SQL DATA
BEGIN
    DECLARE v_active   BOOLEAN DEFAULT FALSE;
    DECLARE v_conflicts INT    DEFAULT 0;

    SELECT is_active INTO v_active FROM doctors WHERE doctor_id = p_doctor_id;
    IF v_active IS NULL OR v_active = FALSE THEN
        RETURN FALSE;
    END IF;

    SELECT COUNT(*) INTO v_conflicts
      FROM appointments
     WHERE doctor_id        = p_doctor_id
       AND appointment_date = p_date
       AND appointment_time = p_time
       AND status IN ('Scheduled','Confirmed');

    RETURN v_conflicts = 0;
END$$

-- ============================================================================
-- MEMBER 2 — FUNCTIONS
-- ============================================================================

DROP FUNCTION IF EXISTS fn_count_prescription_medicines$$
CREATE FUNCTION fn_count_prescription_medicines(p_prescription_id INT)
RETURNS INT
READS SQL DATA
BEGIN
    DECLARE v_count INT DEFAULT 0;
    SELECT COUNT(DISTINCT medicine_id) INTO v_count
      FROM prescription_items
     WHERE prescription_id = p_prescription_id;
    RETURN v_count;
END$$

DROP FUNCTION IF EXISTS fn_calculate_prescription_quantity$$
CREATE FUNCTION fn_calculate_prescription_quantity(p_prescription_id INT)
RETURNS INT
READS SQL DATA
BEGIN
    DECLARE v_total INT DEFAULT 0;
    SELECT COALESCE(SUM(quantity), 0) INTO v_total
      FROM prescription_items
     WHERE prescription_id = p_prescription_id;
    RETURN v_total;
END$$

DROP FUNCTION IF EXISTS fn_find_pending_lab_count$$
CREATE FUNCTION fn_find_pending_lab_count(p_patient_id INT)
RETURNS INT
READS SQL DATA
BEGIN
    DECLARE v_count INT DEFAULT 0;
    SELECT COUNT(*) INTO v_count
      FROM lab_orders
     WHERE patient_id = p_patient_id
       AND status IN ('Pending','In-Progress');   -- FIX: in-progress is still pending work
    RETURN v_count;
END$$

-- ============================================================================
-- MEMBER 3 — FUNCTIONS
-- ============================================================================

DROP FUNCTION IF EXISTS fn_calculate_bill_subtotal$$
CREATE FUNCTION fn_calculate_bill_subtotal(p_bill_id INT)
RETURNS DECIMAL(12,2)
READS SQL DATA
BEGIN
    DECLARE v_subtotal DECIMAL(12,2) DEFAULT 0.00;
    SELECT COALESCE(SUM(amount), 0) INTO v_subtotal
      FROM bill_items
     WHERE bill_id = p_bill_id;
    RETURN v_subtotal;
END$$

-- FIX vs original: the original did  total - paid  with no COALESCE, so a
-- missing bill produced NULL arithmetic silently. Now it returns 0.00.
DROP FUNCTION IF EXISTS fn_calculate_bill_balance$$
CREATE FUNCTION fn_calculate_bill_balance(p_bill_id INT)
RETURNS DECIMAL(12,2)
READS SQL DATA
BEGIN
    DECLARE v_balance DECIMAL(12,2) DEFAULT 0.00;
    SELECT COALESCE(total_amount - paid_amount, 0) INTO v_balance
      FROM bills
     WHERE bill_id = p_bill_id;
    RETURN COALESCE(v_balance, 0.00);
END$$

-- FIX vs original: the policy must be ACTIVE **and within its validity window**.
-- The original happily applied an expired policy.
DROP FUNCTION IF EXISTS fn_calculate_insurance_covered_amount$$
CREATE FUNCTION fn_calculate_insurance_covered_amount(p_bill_id INT)
RETURNS DECIMAL(12,2)
READS SQL DATA
BEGIN
    DECLARE v_total      DECIMAL(12,2) DEFAULT 0.00;
    DECLARE v_patient_id INT;
    DECLARE v_coverage   DECIMAL(5,2)  DEFAULT 0.00;

    SELECT total_amount, patient_id INTO v_total, v_patient_id
      FROM bills WHERE bill_id = p_bill_id;

    IF v_patient_id IS NULL THEN
        RETURN 0.00;
    END IF;

    SELECT COALESCE(MAX(coverage_percentage), 0) INTO v_coverage
      FROM insurance_profiles
     WHERE patient_id = v_patient_id
       AND is_active  = TRUE
       AND valid_from <= CURDATE()
       AND (valid_to IS NULL OR valid_to >= CURDATE());

    RETURN ROUND(v_total * (v_coverage / 100), 2);
END$$

-- ============================================================================
-- MEMBER 4 — FUNCTIONS
-- ============================================================================

DROP FUNCTION IF EXISTS fn_calculate_available_stock$$
CREATE FUNCTION fn_calculate_available_stock(p_medicine_id INT)
RETURNS INT
READS SQL DATA
BEGIN
    DECLARE v_stock INT DEFAULT 0;
    -- Expired batches are NOT sellable stock. Uses idx_inventory_batches_medicine_expiry.
    SELECT COALESCE(SUM(quantity_available), 0) INTO v_stock
      FROM inventory_batches
     WHERE medicine_id = p_medicine_id
       AND expiry_date >= CURDATE();
    RETURN v_stock;
END$$

DROP FUNCTION IF EXISTS fn_check_reorder_requirement$$
CREATE FUNCTION fn_check_reorder_requirement(p_medicine_id INT)
RETURNS BOOLEAN
READS SQL DATA
BEGIN
    DECLARE v_stock         INT DEFAULT 0;
    DECLARE v_reorder_level INT DEFAULT NULL;

    SET v_stock = fn_calculate_available_stock(p_medicine_id);
    SELECT reorder_level INTO v_reorder_level
      FROM medicines WHERE medicine_id = p_medicine_id;

    IF v_reorder_level IS NULL THEN
        RETURN FALSE;                     -- unknown medicine
    END IF;
    RETURN v_stock <= v_reorder_level;
END$$

DROP FUNCTION IF EXISTS fn_calculate_stock_value$$
CREATE FUNCTION fn_calculate_stock_value(p_medicine_id INT)
RETURNS DECIMAL(14,2)
READS SQL DATA
BEGIN
    DECLARE v_value DECIMAL(14,2) DEFAULT 0.00;
    SELECT COALESCE(SUM(quantity_available * purchase_price), 0) INTO v_value
      FROM inventory_batches
     WHERE medicine_id = p_medicine_id
       AND expiry_date >= CURDATE();
    RETURN v_value;
END$$

-- ============================================================================
-- MEMBER 5 — FUNCTIONS
-- ============================================================================

DROP FUNCTION IF EXISTS fn_check_user_permission$$
CREATE FUNCTION fn_check_user_permission(p_user_id INT, p_permission_name VARCHAR(50))
RETURNS BOOLEAN
READS SQL DATA
BEGIN
    DECLARE v_count INT DEFAULT 0;
    -- FIX vs original: an inactive user must never pass a permission check.
    SELECT COUNT(*) INTO v_count
      FROM users u
      JOIN user_roles       ur ON ur.user_id       = u.user_id
      JOIN role_permissions rp ON rp.role_id       = ur.role_id
      JOIN permissions      p  ON p.permission_id  = rp.permission_id
     WHERE u.user_id   = p_user_id
       AND u.is_active = TRUE
       AND p.permission_name = p_permission_name;
    RETURN v_count > 0;
END$$

DROP FUNCTION IF EXISTS fn_count_audit_events$$
CREATE FUNCTION fn_count_audit_events(p_entity_name VARCHAR(50),
                                      p_from DATETIME, p_to DATETIME)
RETURNS INT
READS SQL DATA
BEGIN
    DECLARE v_count INT DEFAULT 0;
    -- Half-open range [from, to) so it is SARGable and uses idx_audit_logs_created_at.
    SELECT COUNT(*) INTO v_count
      FROM audit_logs
     WHERE entity_name = p_entity_name
       AND created_at >= p_from
       AND created_at <  p_to;
    RETURN v_count;
END$$

DROP FUNCTION IF EXISTS fn_return_audit_activity_summary$$
CREATE FUNCTION fn_return_audit_activity_summary(p_user_id INT)
RETURNS VARCHAR(255)
READS SQL DATA
BEGIN
    DECLARE v_summary VARCHAR(255);
    SELECT CONCAT(COUNT(*), ' events (',
                  SUM(action = 'INSERT'), ' insert, ',
                  SUM(action = 'UPDATE'), ' update, ',
                  SUM(action = 'DELETE'), ' delete, ',
                  SUM(action IN ('LOGIN','LOGOUT')), ' session)')
      INTO v_summary
      FROM audit_logs
     WHERE user_id = p_user_id;
    RETURN COALESCE(v_summary, '0 events');
END$$

DELIMITER ;

-- ============================================================================
-- ============================================================================
--  VIEWS  (3 per member)
