-- ##  STAGE 7  --  06_transactions_L9_L10.sql
-- ############################################################################

-- ============================================================================
--  FILE 06 of 08 : TRANSACTION MANAGEMENT  (L9 - L10)
--  10 explicit transactions — 2 per member — each with a COMMIT path AND a
--  ROLLBACK path, written as raw SQL you can paste into MySQL Workbench and
--  run line by line in front of the examiner.
-- ============================================================================
--
--  ACID, mapped onto THIS database:
--
--  A - Atomicity   : sp_create_prescription_with_items writes a header row and
--                    N item rows. Either all appear or none do. Enforced by
--                    START TRANSACTION ... COMMIT plus the EXIT HANDLER's
--                    ROLLBACK.
--  C - Consistency : every committed state satisfies the constraints -
--                    paid_amount <= total_amount, quantity_available >= 0,
--                    UNIQUE(active_slot_key), and every FK.
--  I - Isolation   : InnoDB row locks + MVCC. Demonstrated in file 08.
--  D - Durability  : once COMMIT returns, the redo log is on disk. Even a
--                    power cut cannot lose it (with the default
--                    innodb_flush_log_at_trx_commit = 1).
--
--  BEFORE YOU START — show the examiner your settings:
-- ============================================================================

USE hospital_management;

SELECT @@autocommit                        AS autocommit_is_on,
       @@transaction_isolation             AS isolation_level,
       @@innodb_flush_log_at_trx_commit     AS durability_setting,
       @@innodb_lock_wait_timeout           AS lock_wait_timeout_seconds;

-- autocommit = 1 means EVERY single statement is its own transaction.
-- START TRANSACTION suspends that until COMMIT or ROLLBACK.

SET @app_user_id = 1;    -- so the audit triggers know who is acting

-- ============================================================================
-- ############################################################################
-- MEMBER 1 — PATIENT & APPOINTMENT
-- ############################################################################
-- ============================================================================

-- ----------------------------------------------------------------------------
-- T1.1  BOOK APPOINTMENT TRANSACTION  (COMMIT path)
--       Steps: check patient -> lock doctor -> check slot -> insert -> commit
-- ----------------------------------------------------------------------------
START TRANSACTION;

    -- Step 1: does the patient exist and is the account live?
    SELECT patient_id, CONCAT(first_name,' ',last_name) AS patient
      FROM patients
     WHERE patient_id = 101 AND is_active = TRUE;

    -- Step 2: X-lock the doctor row. Any other booking transaction for THIS
    -- doctor now blocks here until we finish. This is pessimistic locking.
    SELECT doctor_id, CONCAT(first_name,' ',last_name) AS doctor
      FROM doctors
     WHERE doctor_id = 7 AND is_active = TRUE
     FOR UPDATE;

    -- Step 3: is the slot free?  (0 = free)
    SELECT COUNT(*) AS conflicting_appointments
      FROM appointments
     WHERE doctor_id = 7
       AND appointment_date = CURDATE() + INTERVAL 40 DAY
       AND appointment_time = '15:00:00'
       AND status IN ('Scheduled','Confirmed');

    -- Step 4: write it
    INSERT INTO appointments (patient_id, doctor_id, appointment_date,
                              appointment_time, status, reason)
    VALUES (101, 7, CURDATE() + INTERVAL 40 DAY, '15:00:00', 'Scheduled',
            'VIVA DEMO - booking transaction');

    SET @new_appt = LAST_INSERT_ID();
    SELECT @new_appt AS appointment_created;

COMMIT;

-- Proof it survived the COMMIT:
SELECT appointment_id, doctor_id, appointment_date, appointment_time, status, active_slot_key
FROM appointments WHERE appointment_id = @new_appt;

-- ----------------------------------------------------------------------------
-- T1.1b BOOK APPOINTMENT TRANSACTION  (ROLLBACK path)
--       Same slot again -> the UNIQUE(active_slot_key) index rejects it.
-- ----------------------------------------------------------------------------
START TRANSACTION;

    INSERT INTO appointments (patient_id, doctor_id, appointment_date,
                              appointment_time, status, reason)
    VALUES (102, 7, CURDATE() + INTERVAL 40 DAY, '15:00:00', 'Scheduled',
            'VIVA DEMO - should fail');
    -- EXPECTED: ERROR 1062 (23000): Duplicate entry '7|....|15:00:00' for key 'uq_active_slot'

ROLLBACK;

SELECT COUNT(*) AS rows_for_that_slot
FROM appointments
WHERE doctor_id = 7
  AND appointment_date = CURDATE() + INTERVAL 40 DAY
  AND appointment_time = '15:00:00'
  AND status IN ('Scheduled','Confirmed');
-- EXPECTED: 1  (the failed insert left nothing behind — ATOMICITY)

-- SAY THIS: the AUTO_INCREMENT counter did NOT roll back. Atomicity protects
-- DATA, not sequence generators — gaps in appointment_id are normal and are
-- not a bug. (SHOW CREATE TABLE appointments; will show the bumped value.)

-- ----------------------------------------------------------------------------
-- T1.2  RESCHEDULE APPOINTMENT TRANSACTION  (with SAVEPOINT)
-- ----------------------------------------------------------------------------
START TRANSACTION;

    SELECT appointment_id, appointment_date, appointment_time, status
      FROM appointments
     WHERE appointment_id = @new_appt
     FOR UPDATE;                        -- lock the row we are about to move

    SAVEPOINT sp_before_move;

    UPDATE appointments
       SET appointment_date = CURDATE() + INTERVAL 41 DAY,
           appointment_time = '16:00:00'
     WHERE appointment_id = @new_appt;

    SELECT appointment_date, appointment_time FROM appointments
     WHERE appointment_id = @new_appt;          -- shows the NEW values

    -- Patient calls back: "keep the old time after all"
    ROLLBACK TO SAVEPOINT sp_before_move;       -- partial undo; txn still open

    SELECT appointment_date, appointment_time FROM appointments
     WHERE appointment_id = @new_appt;          -- back to the ORIGINAL values

    UPDATE appointments SET notes = 'Reschedule cancelled by patient'
     WHERE appointment_id = @new_appt;          -- still inside the same txn

COMMIT;

-- ============================================================================
-- ############################################################################
-- MEMBER 2 — CLINICAL RECORDS
-- ############################################################################
-- ============================================================================

-- ----------------------------------------------------------------------------
-- T2.1  CREATE PRESCRIPTION TRANSACTION  (header + lines = one unit)
-- ----------------------------------------------------------------------------
-- First give the demo appointment a consultation to hang the prescription on.
START TRANSACTION;

    -- The consultation must exist before the prescription: FK + business order
    INSERT INTO consultations (appointment_id, patient_id, doctor_id,
                               chief_complaint, diagnosis, symptoms, treatment_plan)
    SELECT a.appointment_id, a.patient_id, a.doctor_id,
           'VIVA DEMO', 'Acute pharyngitis', 'Sore throat, fever', 'Antibiotics 5 days'
      FROM appointments a
     WHERE a.appointment_id = @new_appt;

    SET @cons = LAST_INSERT_ID();

    INSERT INTO prescriptions (consultation_id, appointment_id, patient_id,
                               doctor_id, status, notes)
    SELECT @cons, c.appointment_id, c.patient_id, c.doctor_id, 'Active', 'VIVA DEMO'
      FROM consultations c WHERE c.consultation_id = @cons;

    SET @pres = LAST_INSERT_ID();

    INSERT INTO prescription_items (prescription_id, medicine_id, dosage, frequency,
                                    duration_days, quantity, instructions)
    VALUES (@pres, 2, '1 tablet', 'Three times daily', 5, 15, 'After meals'),
           (@pres, 1, '1 tablet', 'When needed',      3,  6, 'For fever');

    SELECT @pres AS prescription_id,
           fn_count_prescription_medicines(@pres) AS medicines,
           fn_calculate_prescription_quantity(@pres) AS total_units;

COMMIT;

-- ----------------------------------------------------------------------------
-- T2.1b SAME TRANSACTION, FORCED TO FAIL  (atomicity proof)
--       The 2nd item has quantity 0 -> the BEFORE INSERT trigger raises.
--       Because we ROLLBACK, the prescription HEADER disappears too.
-- ----------------------------------------------------------------------------
SELECT COUNT(*) INTO @pres_before FROM prescriptions;

START TRANSACTION;

    INSERT INTO prescriptions (consultation_id, appointment_id, patient_id,
                               doctor_id, status, notes)
    SELECT @cons, c.appointment_id, c.patient_id, c.doctor_id, 'Active', 'SHOULD VANISH'
      FROM consultations c WHERE c.consultation_id = @cons;

    SET @bad_pres = LAST_INSERT_ID();

    INSERT INTO prescription_items (prescription_id, medicine_id, dosage, quantity)
    VALUES (@bad_pres, 3, '1 tablet', 0);
    -- EXPECTED: ERROR 1644: Prescription quantity must be greater than zero

ROLLBACK;

SELECT @pres_before AS before_count, COUNT(*) AS after_count FROM prescriptions;
-- EXPECTED: identical. The orphan header was undone. THAT is atomicity.

-- ----------------------------------------------------------------------------
-- T2.2  LAB RESULT TRANSACTION  (result + order status close together)
-- ----------------------------------------------------------------------------
START TRANSACTION;

    INSERT INTO lab_orders (appointment_id, patient_id, doctor_id, test_id, priority, status)
    SELECT a.appointment_id, a.patient_id, a.doctor_id, 1, 'Urgent', 'Pending'
      FROM appointments a WHERE a.appointment_id = @new_appt;

    SET @order = LAST_INSERT_ID();

    SELECT order_id, status FROM lab_orders WHERE order_id = @order;   -- Pending

    INSERT INTO lab_results (order_id, result_value, performed_by, remarks, is_abnormal)
    VALUES (@order, '13.4', 'Lab Tech 2', 'Within normal limits', FALSE);

    -- trg_lab_result_ai_close has already flipped the order to Completed
    SELECT order_id, status FROM lab_orders WHERE order_id = @order;   -- Completed

COMMIT;

-- ============================================================================
-- ############################################################################
-- MEMBER 3 — BILLING & PAYMENTS   *** GROUP MAIN L9-L10 DEMONSTRATION ***
-- ############################################################################
-- ============================================================================

-- ----------------------------------------------------------------------------
-- T3.1  CREATE BILL TRANSACTION  (header + items + rolled-up totals)
-- ----------------------------------------------------------------------------
START TRANSACTION;

    INSERT INTO bills (patient_id, appointment_id, subtotal, discount, tax,
                       total_amount, paid_amount, balance_amount, status)
    SELECT a.patient_id, a.appointment_id, 0, 0, 0, 0, 0, 0, 'Pending'
      FROM appointments a WHERE a.appointment_id = @new_appt;

    SET @bill = LAST_INSERT_ID();

    INSERT INTO bill_items (bill_id, service_id, description, quantity, unit_price, amount)
    SELECT @bill, s.service_id, s.service_name, 1, s.price, s.price
      FROM services s WHERE s.service_id IN (1, 3, 8);

    -- Roll the lines up. fn_calculate_bill_subtotal reads bill_items.
    UPDATE bills
       SET subtotal       = fn_calculate_bill_subtotal(@bill),
           tax            = ROUND(fn_calculate_bill_subtotal(@bill) * 0.02, 2),
           total_amount   = ROUND(fn_calculate_bill_subtotal(@bill) * 1.02, 2),
           balance_amount = ROUND(fn_calculate_bill_subtotal(@bill) * 1.02, 2)
     WHERE bill_id = @bill;

    SELECT bill_id, subtotal, tax, total_amount, balance_amount, status
      FROM bills WHERE bill_id = @bill;

COMMIT;

-- ----------------------------------------------------------------------------
-- T3.2  PAYMENT TRANSACTION  (validate -> insert -> derive -> commit)
--       The derived columns are written by trg_payments_ai_apply, NOT here.
-- ----------------------------------------------------------------------------
START TRANSACTION;

    -- Step 1: X-LOCK the bill row. This single line is what makes concurrent
    -- payments safe. Without it, see the lost-update demo in file 08.
    SELECT bill_id, total_amount, paid_amount,
           (total_amount - paid_amount) AS balance
      FROM bills
     WHERE bill_id = @bill
     FOR UPDATE;

    -- Step 2: insert the payment fact (half the bill).
    -- IMPORTANT: this must NOT be written as
    --     INSERT INTO payments ... SELECT ... FROM bills ...
    -- MySQL raises ERROR 1442 ("Can't update table 'bills' in stored
    -- function/trigger because it is already used by statement which invoked
    -- this ... trigger"): the AFTER INSERT trigger trg_payments_ai_apply
    -- UPDATEs bills, but bills is already open for reading in the same
    -- statement. Read the amount into a variable FIRST, then INSERT ... VALUES.
    SELECT ROUND(total_amount / 2, 2) INTO @half
      FROM bills WHERE bill_id = @bill;

    INSERT INTO payments (bill_id, amount, payment_method, reference_number, received_by)
    VALUES (@bill, @half, 'Card', 'VIVA-PAY-1', 'Cashier-1');

    -- Step 3: verify the invariant BEFORE committing
    SELECT bill_id, total_amount, paid_amount, balance_amount, status,
           (paid_amount <= total_amount)                    AS invariant_no_overpay,
           (balance_amount = total_amount - paid_amount)    AS invariant_balance_correct
      FROM bills WHERE bill_id = @bill;
    -- EXPECTED: status = 'Partial', both invariant columns = 1

COMMIT;

-- ----------------------------------------------------------------------------
-- T3.2b PAYMENT TRANSACTION — REJECTED (consistency proof)
--       Try to pay far more than the outstanding balance.
-- ----------------------------------------------------------------------------
START TRANSACTION;

    SELECT paid_amount, balance_amount FROM bills WHERE bill_id = @bill FOR UPDATE;

    INSERT INTO payments (bill_id, amount, payment_method, received_by)
    VALUES (@bill, 999999.00, 'Cash', 'Cashier-1');
    -- EXPECTED: ERROR 1644: Payment exceeds the outstanding balance of this bill

ROLLBACK;

SELECT bill_id, total_amount, paid_amount, balance_amount, status
  FROM bills WHERE bill_id = @bill;
-- EXPECTED: unchanged from T3.2. Nothing leaked out of the failed transaction.

-- Same thing through the stored procedure, showing the SAVEPOINT path too:
CALL sp_process_complete_payment_transaction(
        @bill,                       -- bill
        1.00,                        -- small cash payment
        'Cash', 'VIVA-PAY-2', 'Cashier-2',
        TRUE,                        -- try insurance first (SAVEPOINT branch)
        @out_status, @out_balance);
SELECT @out_status AS status_after, @out_balance AS balance_after;

-- ============================================================================
-- ############################################################################
-- MEMBER 4 — INVENTORY & PHARMACY
-- ############################################################################
-- ============================================================================

-- ----------------------------------------------------------------------------
-- T4.1  RECEIVE STOCK TRANSACTION
-- ----------------------------------------------------------------------------
START TRANSACTION;

    INSERT INTO inventory_batches (medicine_id, batch_number, quantity_received,
                                   quantity_available, manufacture_date, expiry_date,
                                   supplier_name, purchase_price)
    VALUES (1, 'VIVA-BATCH-001', 500, 0,
            CURDATE() - INTERVAL 30 DAY, CURDATE() + INTERVAL 365 DAY,
            'MedSupply Lanka', 4.50);

    SET @batch = LAST_INSERT_ID();

    -- The trigger trg_stock_tx_ai_apply is what actually fills the batch
    INSERT INTO stock_transactions (batch_id, medicine_id, transaction_type,
                                    quantity, performed_by, notes)
    VALUES (@batch, 1, 'Receive', 500, 'Pharm-1', 'VIVA DEMO GRN');

    SELECT batch_id, quantity_received, quantity_available
      FROM inventory_batches WHERE batch_id = @batch;
    -- EXPECTED: received 500, available 500  (counted ONCE, not 1000)

COMMIT;

-- ----------------------------------------------------------------------------
-- T4.2  DISPENSE MEDICINE TRANSACTION  (check -> lock -> reduce -> record)
-- ----------------------------------------------------------------------------
START TRANSACTION;

    -- Step 1: lock the batch and read the true current quantity
    SELECT batch_id, quantity_available
      FROM inventory_batches
     WHERE batch_id = @batch
     FOR UPDATE;

    -- Step 2: record the movement; the trigger decrements the batch
    INSERT INTO stock_transactions (batch_id, medicine_id, transaction_type,
                                    quantity, performed_by, notes)
    VALUES (@batch, 1, 'Dispense', 20, 'Pharm-1', 'VIVA DEMO dispense');

    -- Step 3: record who received it
    INSERT INTO pharmacy_dispensations (prescription_id, patient_id, dispensed_by,
                                        total_items, status)
    SELECT @pres, p.patient_id, 'Pharm-1', 20, 'Completed'
      FROM prescriptions p WHERE p.prescription_id = @pres;

    SELECT quantity_available FROM inventory_batches WHERE batch_id = @batch;
    -- EXPECTED: 480

COMMIT;

-- ----------------------------------------------------------------------------
-- T4.2b DISPENSE MORE THAN EXISTS — rejected, whole transaction rolled back
-- ----------------------------------------------------------------------------
START TRANSACTION;

    SELECT quantity_available FROM inventory_batches WHERE batch_id = @batch FOR UPDATE;

    INSERT INTO stock_transactions (batch_id, medicine_id, transaction_type,
                                    quantity, performed_by)
    VALUES (@batch, 1, 'Dispense', 99999, 'Pharm-1');
    -- EXPECTED: ERROR 1644: STOCK CANNOT GO NEGATIVE: dispense rejected

ROLLBACK;

SELECT quantity_available FROM inventory_batches WHERE batch_id = @batch;
-- EXPECTED: still 480

-- The same logic, FIFO across many batches, through the procedure:
CALL sp_dispense_medicine(@disp, @pres, 1, 30, 'Pharm-2');
SELECT @disp AS dispensation_id;
SELECT batch_id, quantity_available FROM inventory_batches
 WHERE medicine_id = 1 AND expiry_date >= CURDATE()
 ORDER BY expiry_date LIMIT 5;

-- ============================================================================
-- ############################################################################
-- MEMBER 5 — SECURITY & AUDITING
-- ############################################################################
-- ============================================================================

-- ----------------------------------------------------------------------------
-- T5.1  CREATE USER & ROLE TRANSACTION
--       A user with no role can log in but do nothing -> the two inserts MUST
--       be one atomic unit.
-- ----------------------------------------------------------------------------
START TRANSACTION;

    INSERT INTO users (username, password_hash, email, full_name, phone)
    VALUES ('viva_demo', SHA2('S3cret!', 256), 'viva@hospital.lk', 'Viva Demo User', '0771234567');

    SET @uid = LAST_INSERT_ID();

    INSERT INTO user_roles (user_id, role_id, assigned_by)
    SELECT @uid, role_id, 'viva_admin' FROM roles WHERE role_name = 'CASHIER';

    SELECT user_id, username, roles FROM vw_user_role_summary WHERE user_id = @uid;

COMMIT;

-- ----------------------------------------------------------------------------
-- T5.1b SAME TRANSACTION WITH A DUPLICATE USERNAME — rollback proof
-- ----------------------------------------------------------------------------
SELECT COUNT(*) INTO @users_before FROM users;

START TRANSACTION;

    INSERT INTO users (username, password_hash, email, full_name)
    VALUES ('viva_demo2', SHA2('x',256), 'viva2@hospital.lk', 'Second Demo');

    SET @uid2 = LAST_INSERT_ID();

    INSERT INTO user_roles (user_id, role_id, assigned_by)
    SELECT @uid2, role_id, 'viva_admin' FROM roles WHERE role_name = 'CASHIER';

    -- now collide on the UNIQUE username
    INSERT INTO users (username, password_hash, email, full_name)
    VALUES ('viva_demo', SHA2('x',256), 'dup@hospital.lk', 'Duplicate');
    -- EXPECTED: ERROR 1062 Duplicate entry 'viva_demo' for key 'uq_users_username'

ROLLBACK;

SELECT @users_before AS before_count, COUNT(*) AS after_count FROM users;
-- EXPECTED: equal. viva_demo2 AND its role assignment both vanished.

-- ----------------------------------------------------------------------------
-- T5.2  ROLE PERMISSION TRANSACTION  (grant + audit in one unit)
-- ----------------------------------------------------------------------------
SET @app_user_id = @uid;

START TRANSACTION;

    SELECT role_id INTO @role FROM roles WHERE role_name = 'CASHIER';
    SELECT permission_id INTO @perm FROM permissions WHERE permission_name = 'AUDIT_READ';

    INSERT INTO role_permissions (role_id, permission_id) VALUES (@role, @perm);

    -- trg_role_permissions_ai_audit wrote the audit row inside THIS transaction:
    SELECT log_id, user_id, entity_name, action, new_value
      FROM audit_logs
     WHERE entity_name = 'role_permissions'
     ORDER BY log_id DESC LIMIT 1;

COMMIT;

SELECT fn_check_user_permission(@uid, 'AUDIT_READ') AS can_read_audit_now;  -- 1

-- Revoke it again, atomically, through the procedure:
CALL sp_assign_revoke_role_permission(@role, @perm, 'REVOKE', @uid);
SELECT fn_check_user_permission(@uid, 'AUDIT_READ') AS can_read_audit_now;  -- 0

-- ============================================================================
--  CLOSING POINT FOR THE VIVA
--  "Notice that the audit row and the business row are written inside the SAME
--   transaction. If the grant rolls back, the audit entry rolls back with it.
--   An audit log that can disagree with the data it audits is worse than no
--   audit log at all."
-- ============================================================================

-- END OF FILE 06


-- ############################################################################
-- ##  STAGE 8  --  07_optimization_L1_L8.sql
