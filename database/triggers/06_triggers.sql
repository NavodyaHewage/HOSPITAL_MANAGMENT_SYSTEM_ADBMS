-- ############################################################################

-- ============================================================================
--  FILE 05 of 08 : TRIGGERS (15) — 3 per member
-- ============================================================================
--  RUN THIS AFTER THE SEED DATA. Triggers are row-level; firing them 200,000
--  times during a bulk load is slow and would fill audit_logs with noise.
--
--  TWO BUGS FROM THE ORIGINAL FILE ARE FIXED HERE. Be ready to explain both.
--
--  BUG 1 — DOUBLE COUNTING (procedure + trigger both wrote the same column).
--          A payment of 1000 increased paid_amount by 2000. Fixed by the
--          single-owner rule declared in file 04.
--
--  BUG 2 — MySQL EVALUATES A MULTI-COLUMN "SET" LEFT TO RIGHT, AND LATER
--          EXPRESSIONS SEE THE ALREADY-UPDATED VALUE OF EARLIER COLUMNS.
--          The original wrote:
--              SET paid_amount    = paid_amount + NEW.amount,
--                  balance_amount = total_amount - (paid_amount + NEW.amount)
--          By the time balance_amount is computed, paid_amount ALREADY
--          includes NEW.amount, so NEW.amount is subtracted twice.
--          Fix: compute every dependent column FIRST and assign the driving
--          column LAST (see trg_payments_ai_apply).
--          This is a MySQL-specific behaviour; standard SQL evaluates all
--          right-hand sides against the OLD row. Good viva talking point.
-- ============================================================================

USE hospital_management;

DELIMITER $$

-- ============================================================================
-- MEMBER 1 — TRIGGERS (Patient & Appointment)
-- ============================================================================

-- 1/15 : validate new appointments
-- @allow_backdated = 1 lets us load historical demo data on purpose.
DROP TRIGGER IF EXISTS trg_appointments_bi_validate$$
CREATE TRIGGER trg_appointments_bi_validate
BEFORE INSERT ON appointments
FOR EACH ROW
BEGIN
    IF NEW.appointment_date < CURDATE() AND COALESCE(@allow_backdated, 0) <> 1 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Cannot create an appointment in the past';
    END IF;

    IF TIME(NEW.appointment_time) < '07:00:00'
       OR TIME(NEW.appointment_time) > '21:00:00' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Appointment time must be between 07:00 and 21:00';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM doctors
                    WHERE doctor_id = NEW.doctor_id AND is_active = TRUE) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Doctor is inactive or does not exist';
    END IF;
END$$

-- 2/15 : protect the appointment state machine
DROP TRIGGER IF EXISTS trg_appointments_bu_validate$$
CREATE TRIGGER trg_appointments_bu_validate
BEFORE UPDATE ON appointments
FOR EACH ROW
BEGIN
    IF OLD.status = 'Completed' AND NEW.status <> 'Completed' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'A completed appointment cannot be re-opened';
    END IF;

    IF OLD.status = 'Cancelled' AND NEW.status IN ('Completed','No-Show') THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'A cancelled appointment cannot be completed';
    END IF;

    -- Rescheduling into the past is not allowed either
    IF NEW.appointment_date < CURDATE()
       AND NEW.appointment_date <> OLD.appointment_date
       AND COALESCE(@allow_backdated, 0) <> 1 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Cannot reschedule into the past';
    END IF;
END$$

-- 3/15 : audit patient changes (only when something actually changed)
DROP TRIGGER IF EXISTS trg_patients_au_audit$$
CREATE TRIGGER trg_patients_au_audit
AFTER UPDATE ON patients
FOR EACH ROW
BEGIN
    IF NOT (OLD.phone   <=> NEW.phone)
    OR NOT (OLD.address <=> NEW.address)
    OR NOT (OLD.email   <=> NEW.email)
    OR NOT (OLD.is_active <=> NEW.is_active) THEN
        INSERT INTO audit_logs (user_id, entity_name, entity_id, action, old_value, new_value)
        VALUES (@app_user_id, 'patients', OLD.patient_id, 'UPDATE',
                CONCAT_WS(' | ', CONCAT('phone=',   COALESCE(OLD.phone,'')),
                                 CONCAT('email=',   COALESCE(OLD.email,'')),
                                 CONCAT('address=', COALESCE(OLD.address,'')),
                                 CONCAT('active=',  OLD.is_active)),
                CONCAT_WS(' | ', CONCAT('phone=',   COALESCE(NEW.phone,'')),
                                 CONCAT('email=',   COALESCE(NEW.email,'')),
                                 CONCAT('address=', COALESCE(NEW.address,'')),
                                 CONCAT('active=',  NEW.is_active)));
    END IF;
END$$

-- ============================================================================
-- MEMBER 2 — TRIGGERS (Clinical Records)
-- ============================================================================

-- 4/15 : audit diagnosis edits — a changed diagnosis is a medico-legal event
DROP TRIGGER IF EXISTS trg_consultations_au_audit$$
CREATE TRIGGER trg_consultations_au_audit
AFTER UPDATE ON consultations
FOR EACH ROW
BEGIN
    IF NOT (OLD.diagnosis <=> NEW.diagnosis)
    OR NOT (OLD.treatment_plan <=> NEW.treatment_plan) THEN
        INSERT INTO audit_logs (user_id, entity_name, entity_id, action, old_value, new_value)
        VALUES (@app_user_id, 'consultations', OLD.consultation_id, 'UPDATE',
                LEFT(CONCAT('dx=', COALESCE(OLD.diagnosis,'')), 2000),
                LEFT(CONCAT('dx=', COALESCE(NEW.diagnosis,'')), 2000));
    END IF;
END$$

-- 5/15 : prescription line validation (defence in depth over the CHECK)
DROP TRIGGER IF EXISTS trg_prescription_items_bi_validate$$
CREATE TRIGGER trg_prescription_items_bi_validate
BEFORE INSERT ON prescription_items
FOR EACH ROW
BEGIN
    IF NEW.quantity <= 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Prescription quantity must be greater than zero';
    END IF;

    IF NEW.duration_days IS NOT NULL AND NEW.duration_days > 180 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Duration over 180 days needs a specialist override';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM medicines
                    WHERE medicine_id = NEW.medicine_id AND is_active = TRUE) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Medicine is discontinued or does not exist';
    END IF;
END$$

-- 6/15 : *** OWNER of lab_orders.status *** — entering a result closes the order
DROP TRIGGER IF EXISTS trg_lab_result_ai_close$$
CREATE TRIGGER trg_lab_result_ai_close
AFTER INSERT ON lab_results
FOR EACH ROW
BEGIN
    UPDATE lab_orders
       SET status = 'Completed'
     WHERE order_id = NEW.order_id
       AND status <> 'Cancelled';        -- never resurrect a cancelled order

    INSERT INTO audit_logs (user_id, entity_name, entity_id, action, new_value)
    VALUES (@app_user_id, 'lab_results', NEW.result_id, 'INSERT',
            CONCAT('order=', NEW.order_id, ', value=', COALESCE(NEW.result_value,''),
                   ', abnormal=', NEW.is_abnormal));
END$$

-- ============================================================================
-- MEMBER 3 — TRIGGERS (Billing & Payments)
-- ============================================================================

-- 7/15 : reject nonsense payments before they touch the ledger
DROP TRIGGER IF EXISTS trg_payments_bi_validate$$
CREATE TRIGGER trg_payments_bi_validate
BEFORE INSERT ON payments
FOR EACH ROW
BEGIN
    DECLARE v_balance DECIMAL(12,2) DEFAULT NULL;
    DECLARE v_status  VARCHAR(20)   DEFAULT NULL;

    IF NEW.amount <= 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Payment amount must be positive';
    END IF;

    SELECT total_amount - paid_amount, status
      INTO v_balance, v_status
      FROM bills WHERE bill_id = NEW.bill_id;

    IF v_status = 'Cancelled' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Cannot pay a cancelled bill';
    END IF;

    -- THE OVERPAYMENT GUARD. In the concurrency demo (file 08) two sessions
    -- each pass this check on the OLD value; the row lock is what makes the
    -- second one re-read and fail. Constraint + lock together, not either alone.
    IF v_balance IS NOT NULL AND NEW.amount > v_balance THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Payment exceeds the outstanding balance of this bill';
    END IF;
END$$

-- 8/15 : *** OWNER of bills.paid_amount / balance_amount / status ***
--        Note the SET order: paid_amount is assigned LAST (see BUG 2 above).
DROP TRIGGER IF EXISTS trg_payments_ai_apply$$
CREATE TRIGGER trg_payments_ai_apply
AFTER INSERT ON payments
FOR EACH ROW
BEGIN
    UPDATE bills
       SET balance_amount = total_amount - (paid_amount + NEW.amount),
           status = CASE
                      WHEN (paid_amount + NEW.amount) >= total_amount THEN 'Paid'
                      WHEN (paid_amount + NEW.amount) > 0             THEN 'Partial'
                      ELSE 'Pending'
                    END,
           paid_amount = paid_amount + NEW.amount     -- assigned LAST, on purpose
     WHERE bill_id = NEW.bill_id;
END$$

-- 9/15 : money audit trail
DROP TRIGGER IF EXISTS trg_payments_ai_audit$$
CREATE TRIGGER trg_payments_ai_audit
AFTER INSERT ON payments
FOR EACH ROW
BEGIN
    INSERT INTO audit_logs (user_id, entity_name, entity_id, action, new_value)
    VALUES (@app_user_id, 'payments', NEW.payment_id, 'INSERT',
            CONCAT('bill=', NEW.bill_id, ', amount=', NEW.amount,
                   ', method=', NEW.payment_method,
                   ', ref=', COALESCE(NEW.reference_number,'-')));
END$$

-- ============================================================================
-- MEMBER 4 — TRIGGERS (Inventory & Pharmacy)
-- ============================================================================

-- 10/15 : *** OWNER of inventory_batches.quantity_available ***
--         The sign of the movement comes from transaction_type; quantity is
--         always stored positive (CHECK quantity > 0).
DROP TRIGGER IF EXISTS trg_stock_tx_ai_apply$$
CREATE TRIGGER trg_stock_tx_ai_apply
AFTER INSERT ON stock_transactions
FOR EACH ROW
BEGIN
    IF NEW.transaction_type IN ('Receive','Return') THEN
        UPDATE inventory_batches
           SET quantity_available = quantity_available + NEW.quantity
         WHERE batch_id = NEW.batch_id;
    ELSE   -- 'Dispense' or 'Adjustment' -> stock goes out
        UPDATE inventory_batches
           SET quantity_available = quantity_available - NEW.quantity
         WHERE batch_id = NEW.batch_id;
    END IF;
END$$

-- 11/15 : friendly guard on the negative-stock invariant.
--         The CHECK constraint already blocks it, but raises a cryptic
--         "Check constraint violated" (error 3819). This gives a readable
--         message AND documents the invariant where a reviewer will see it.
DROP TRIGGER IF EXISTS trg_inventory_bu_prevent_negative$$
CREATE TRIGGER trg_inventory_bu_prevent_negative
BEFORE UPDATE ON inventory_batches
FOR EACH ROW
BEGIN
    IF NEW.quantity_available < 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'STOCK CANNOT GO NEGATIVE: dispense rejected';
    END IF;

    IF NEW.quantity_available > NEW.quantity_received THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Available quantity cannot exceed the quantity received';
    END IF;
END$$

-- 12/15 : pharmacy audit trail
DROP TRIGGER IF EXISTS trg_stock_tx_ai_audit$$
CREATE TRIGGER trg_stock_tx_ai_audit
AFTER INSERT ON stock_transactions
FOR EACH ROW
BEGIN
    INSERT INTO audit_logs (user_id, entity_name, entity_id, action, new_value)
    VALUES (@app_user_id, 'stock_transactions', NEW.transaction_id, 'INSERT',
            CONCAT('batch=', NEW.batch_id, ', medicine=', NEW.medicine_id,
                   ', type=', NEW.transaction_type, ', qty=', NEW.quantity));
END$$

-- ============================================================================
-- MEMBER 5 — TRIGGERS (Security & Auditing)
-- ============================================================================

-- 13/15 : record every new account
DROP TRIGGER IF EXISTS trg_users_ai_audit$$
CREATE TRIGGER trg_users_ai_audit
AFTER INSERT ON users
FOR EACH ROW
BEGIN
    INSERT INTO audit_logs (user_id, entity_name, entity_id, action, new_value)
    VALUES (@app_user_id, 'users', NEW.user_id, 'INSERT',
            CONCAT('username=', NEW.username, ', name=', NEW.full_name));
END$$

-- 14/15 : session tracking — LOGIN and LOGOUT (the original only did LOGIN)
DROP TRIGGER IF EXISTS trg_users_au_session$$
CREATE TRIGGER trg_users_au_session
AFTER UPDATE ON users
FOR EACH ROW
BEGIN
    IF NOT (OLD.last_login <=> NEW.last_login) AND NEW.last_login IS NOT NULL THEN
        INSERT INTO audit_logs (user_id, entity_name, entity_id, action, new_value)
        VALUES (NEW.user_id, 'users', NEW.user_id, 'LOGIN', CONCAT('at=', NEW.last_login));
    END IF;

    IF NOT (OLD.last_logout <=> NEW.last_logout) AND NEW.last_logout IS NOT NULL THEN
        INSERT INTO audit_logs (user_id, entity_name, entity_id, action, new_value)
        VALUES (NEW.user_id, 'users', NEW.user_id, 'LOGOUT', CONCAT('at=', NEW.last_logout));
    END IF;

    IF NOT (OLD.is_active <=> NEW.is_active) THEN
        INSERT INTO audit_logs (user_id, entity_name, entity_id, action, old_value, new_value)
        VALUES (@app_user_id, 'users', NEW.user_id, 'UPDATE',
                CONCAT('is_active=', OLD.is_active), CONCAT('is_active=', NEW.is_active));
    END IF;
END$$

-- 15/15 : privilege escalation is the single most security-sensitive event
DROP TRIGGER IF EXISTS trg_role_permissions_ai_audit$$
CREATE TRIGGER trg_role_permissions_ai_audit
AFTER INSERT ON role_permissions
FOR EACH ROW
BEGIN
    INSERT INTO audit_logs (user_id, entity_name, entity_id, action, new_value)
    VALUES (@app_user_id, 'role_permissions', NEW.role_permission_id, 'INSERT',
            CONCAT('role=', NEW.role_id, ' granted permission=', NEW.permission_id));
END$$

DELIMITER ;

-- ============================================================================
-- VERIFY
-- ============================================================================
SELECT TRIGGER_NAME, EVENT_MANIPULATION AS event, ACTION_TIMING AS timing,
       EVENT_OBJECT_TABLE AS on_table
FROM information_schema.TRIGGERS
WHERE TRIGGER_SCHEMA = 'hospital_management'
ORDER BY EVENT_OBJECT_TABLE, ACTION_TIMING, TRIGGER_NAME;
-- Expected: 15 rows

-- ============================================================================
-- PROOF THAT BUG 1 AND BUG 2 ARE GONE  (run this live in the viva)
-- ============================================================================
SET @app_user_id = 1;

-- pick an unpaid bill
SELECT bill_id, total_amount, paid_amount, balance_amount, status
INTO @b, @tot, @paid, @bal, @st
FROM bills WHERE status = 'Pending' ORDER BY bill_id LIMIT 1;

SELECT @b AS bill_id, @tot AS total, @paid AS paid_before, @bal AS balance_before;

-- pay exactly half
CALL sp_record_payment(@pid, @b, ROUND(@tot/2, 2), 'Cash', 'VIVA-TEST-1', 'demo');

SELECT bill_id, total_amount, paid_amount, balance_amount, status
FROM bills WHERE bill_id = @b;
-- EXPECTED: paid_amount = total/2  (NOT total, which is what the double-count bug gave)
--           balance_amount = total/2  (NOT 0 or negative, which BUG 2 gave)
--           status = 'Partial'

-- END OF FILE 05


-- ############################################################################
-- ##  STAGE 6  --  FINAL VERIFICATION
