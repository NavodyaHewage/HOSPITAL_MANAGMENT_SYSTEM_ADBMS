-- ############################################################################

-- ============================================================================
--  FILE 04 of 08 : STORED PROCEDURES (15) — 3 per member  + 1 utility
-- ============================================================================
--  THE RULE THAT MAKES THIS DATABASE CORRECT — memorise it for the viva:
--
--      "EVERY DERIVED COLUMN HAS EXACTLY ONE OWNER."
--
--  In the original file BOTH a procedure AND a trigger updated the same
--  derived column, so every payment was counted twice and every dispense
--  removed stock twice. Here:
--
--      bills.paid_amount / balance_amount / status
--            -> owned by trigger trg_payments_ai_apply   (file 05)
--      inventory_batches.quantity_available
--            -> owned by trigger trg_stock_tx_ai_apply   (file 05)
--      lab_orders.status
--            -> owned by trigger trg_lab_result_ai_close (file 05)
--
--  Procedures below therefore INSERT the fact (a payment row, a stock
--  transaction row) and let the trigger derive the consequence. They never
--  write those columns themselves.
--
--  ERROR HANDLING PATTERN used in every writing procedure:
--      DECLARE EXIT HANDLER FOR SQLEXCEPTION
--      BEGIN ROLLBACK; RESIGNAL; END;
--  Without this, a failure in the middle of a multi-statement procedure leaves
--  the transaction half-applied and open  -> ATOMICITY is violated.
-- ============================================================================

USE hospital_management;

DELIMITER $$

-- ============================================================================
-- MEMBER 1 — PROCEDURES
-- ============================================================================

DROP PROCEDURE IF EXISTS sp_register_or_update_patient$$
CREATE PROCEDURE sp_register_or_update_patient(
    INOUT p_patient_id            INT,
    IN    p_first_name            VARCHAR(50),
    IN    p_last_name             VARCHAR(50),
    IN    p_date_of_birth         DATE,
    IN    p_gender                VARCHAR(10),
    IN    p_blood_group           VARCHAR(5),
    IN    p_phone                 VARCHAR(20),
    IN    p_email                 VARCHAR(100),
    IN    p_address               VARCHAR(255),
    IN    p_emergency_name        VARCHAR(100),
    IN    p_emergency_phone       VARCHAR(20),
    IN    p_national_id           VARCHAR(30)
)
MODIFIES SQL DATA
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    IF p_date_of_birth > CURDATE() THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Date of birth cannot be in the future';
    END IF;

    START TRANSACTION;

    IF p_patient_id IS NULL
       OR NOT EXISTS (SELECT 1 FROM patients WHERE patient_id = p_patient_id) THEN

        INSERT INTO patients (first_name, last_name, date_of_birth, gender, blood_group,
                              phone, email, address, emergency_contact_name,
                              emergency_contact_phone, national_id)
        VALUES (p_first_name, p_last_name, p_date_of_birth, p_gender, p_blood_group,
                p_phone, p_email, p_address, p_emergency_name,
                p_emergency_phone, p_national_id);

        SET p_patient_id = LAST_INSERT_ID();   -- INOUT: caller gets the new id
    ELSE
        UPDATE patients
           SET first_name = p_first_name,
               last_name  = p_last_name,
               date_of_birth = p_date_of_birth,
               gender     = p_gender,
               blood_group = p_blood_group,
               phone      = p_phone,
               email      = p_email,
               address    = p_address,
               emergency_contact_name  = p_emergency_name,
               emergency_contact_phone = p_emergency_phone,
               national_id = p_national_id
         WHERE patient_id = p_patient_id;
    END IF;

    COMMIT;
END$$

-- ----------------------------------------------------------------------------
-- THE APPOINTMENT BOOKING PROCEDURE — the centrepiece of Member 1's L9-L13.
-- Three layers of defence against a double booking:
--   1. pessimistic lock : SELECT ... FOR UPDATE on the doctor row serialises
--                          two concurrent bookings for the SAME doctor
--   2. logical check    : fn_check_doctor_availability gives a friendly error
--   3. declarative      : UNIQUE(active_slot_key) - the engine's last word,
--                          caught below as MySQL error 1062
-- Layer 3 is the only one that is safe on its own. 1 and 2 exist to turn a
-- raw duplicate-key error into a clean business message.
-- ----------------------------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_book_or_reschedule_appointment$$
CREATE PROCEDURE sp_book_or_reschedule_appointment(
    INOUT p_appointment_id INT,
    IN    p_patient_id     INT,
    IN    p_doctor_id      INT,
    IN    p_date           DATE,
    IN    p_time           TIME,
    IN    p_reason         VARCHAR(255)
)
MODIFIES SQL DATA
BEGIN
    DECLARE v_dummy INT;

    -- 1062 = ER_DUP_ENTRY -> somebody else won the race on active_slot_key
    DECLARE EXIT HANDLER FOR 1062
    BEGIN
        ROLLBACK;
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'SLOT ALREADY BOOKED: another user took this doctor/date/time';
    END;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    IF p_date < CURDATE() THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Cannot book an appointment in the past';
    END IF;

    START TRANSACTION;

    -- Pessimistic lock on the doctor row (X-lock held until COMMIT)
    SELECT doctor_id INTO v_dummy
      FROM doctors
     WHERE doctor_id = p_doctor_id AND is_active = TRUE
     FOR UPDATE;

    IF v_dummy IS NULL THEN
        ROLLBACK;
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Doctor not found or inactive';
    END IF;

    IF NOT fn_check_doctor_availability(p_doctor_id, p_date, p_time) THEN
        ROLLBACK;
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Doctor is not available at that date/time';
    END IF;

    IF p_appointment_id IS NULL THEN
        INSERT INTO appointments (patient_id, doctor_id, appointment_date,
                                  appointment_time, reason, status)
        VALUES (p_patient_id, p_doctor_id, p_date, p_time, p_reason, 'Scheduled');
        SET p_appointment_id = LAST_INSERT_ID();
    ELSE
        UPDATE appointments
           SET doctor_id        = p_doctor_id,
               appointment_date = p_date,
               appointment_time = p_time,
               reason           = p_reason,
               status           = 'Scheduled'
         WHERE appointment_id = p_appointment_id
           AND status IN ('Scheduled','Confirmed');

        IF ROW_COUNT() = 0 THEN
            ROLLBACK;
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'Appointment not found, or it is completed/cancelled';
        END IF;
    END IF;

    COMMIT;
END$$

-- FIX vs original: the original excluded any doctor who had ANY appointment
-- that day, so a doctor with one 8am patient looked "busy" for 24 hours.
-- This version checks the requested TIME SLOT only.
DROP PROCEDURE IF EXISTS sp_search_doctor_availability$$
CREATE PROCEDURE sp_search_doctor_availability(
    IN p_department_id INT,
    IN p_date          DATE,
    IN p_time          TIME
)
READS SQL DATA
BEGIN
    SELECT d.doctor_id,
           CONCAT(d.first_name,' ',d.last_name) AS doctor_name,
           d.specialization,
           d.consultation_fee,
           (SELECT COUNT(*) FROM appointments a
             WHERE a.doctor_id = d.doctor_id
               AND a.appointment_date = p_date
               AND a.status IN ('Scheduled','Confirmed')) AS bookings_that_day
    FROM doctors d
    WHERE (p_department_id IS NULL OR d.department_id = p_department_id)
      AND d.is_active = TRUE
      AND NOT EXISTS (
            SELECT 1 FROM appointments a
             WHERE a.doctor_id        = d.doctor_id
               AND a.appointment_date = p_date
               AND a.appointment_time = p_time
               AND a.status IN ('Scheduled','Confirmed'))
    ORDER BY bookings_that_day, d.doctor_id;
END$$

-- ============================================================================
-- MEMBER 2 — PROCEDURES
-- ============================================================================

DROP PROCEDURE IF EXISTS sp_create_consultation$$
CREATE PROCEDURE sp_create_consultation(
    INOUT p_consultation_id INT,
    IN    p_appointment_id  INT,
    IN    p_chief_complaint VARCHAR(255),
    IN    p_diagnosis       TEXT,
    IN    p_symptoms        TEXT,
    IN    p_treatment_plan  TEXT,
    IN    p_follow_up_date  DATE
)
MODIFIES SQL DATA
BEGIN
    DECLARE v_patient_id INT DEFAULT NULL;
    DECLARE v_doctor_id  INT DEFAULT NULL;
    DECLARE v_status     VARCHAR(20);

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    -- Lock the appointment: it is about to change state to 'Completed'
    SELECT patient_id, doctor_id, status
      INTO v_patient_id, v_doctor_id, v_status
      FROM appointments
     WHERE appointment_id = p_appointment_id
     FOR UPDATE;

    IF v_patient_id IS NULL THEN
        ROLLBACK;
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Appointment does not exist';
    END IF;

    IF v_status IN ('Cancelled','No-Show') THEN
        ROLLBACK;
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Cannot consult on a cancelled/no-show appointment';
    END IF;

    INSERT INTO consultations (appointment_id, patient_id, doctor_id, chief_complaint,
                               diagnosis, symptoms, treatment_plan, follow_up_date)
    VALUES (p_appointment_id, v_patient_id, v_doctor_id, p_chief_complaint,
            p_diagnosis, p_symptoms, p_treatment_plan, p_follow_up_date);

    SET p_consultation_id = LAST_INSERT_ID();

    UPDATE appointments SET status = 'Completed' WHERE appointment_id = p_appointment_id;

    COMMIT;
END$$

-- ----------------------------------------------------------------------------
-- Prescription + its items in ONE atomic unit.
-- Items arrive as a JSON array so the whole prescription is a single call:
--   '[{"medicine_id":1,"dosage":"1 tablet","frequency":"BD","duration_days":5,
--      "quantity":10,"instructions":"After meals"}, {...}]'
-- Header and lines commit together or not at all — that is ATOMICITY.
-- ----------------------------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_create_prescription_with_items$$
CREATE PROCEDURE sp_create_prescription_with_items(
    INOUT p_prescription_id INT,
    IN    p_consultation_id INT,
    IN    p_items_json      JSON,
    IN    p_notes           TEXT
)
MODIFIES SQL DATA
BEGIN
    DECLARE v_appointment_id INT DEFAULT NULL;
    DECLARE v_patient_id     INT DEFAULT NULL;
    DECLARE v_doctor_id      INT DEFAULT NULL;
    DECLARE v_item_count     INT DEFAULT 0;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    IF p_items_json IS NULL OR JSON_LENGTH(p_items_json) = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'A prescription must have at least one item';
    END IF;

    START TRANSACTION;

    SELECT appointment_id, patient_id, doctor_id
      INTO v_appointment_id, v_patient_id, v_doctor_id
      FROM consultations
     WHERE consultation_id = p_consultation_id;

    IF v_patient_id IS NULL THEN
        ROLLBACK;
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Consultation does not exist';
    END IF;

    INSERT INTO prescriptions (consultation_id, appointment_id, patient_id,
                               doctor_id, status, notes)
    VALUES (p_consultation_id, v_appointment_id, v_patient_id, v_doctor_id, 'Active', p_notes);

    SET p_prescription_id = LAST_INSERT_ID();

    INSERT INTO prescription_items (prescription_id, medicine_id, dosage, frequency,
                                    duration_days, quantity, instructions)
    SELECT p_prescription_id, j.medicine_id, j.dosage, j.frequency,
           j.duration_days, j.quantity, j.instructions
    FROM JSON_TABLE(p_items_json, '$[*]' COLUMNS (
             medicine_id   INT          PATH '$.medicine_id',
             dosage        VARCHAR(50)  PATH '$.dosage',
             frequency     VARCHAR(50)  PATH '$.frequency',
             duration_days INT          PATH '$.duration_days',
             quantity      INT          PATH '$.quantity',
             instructions  VARCHAR(255) PATH '$.instructions'
         )) AS j;

    SET v_item_count = ROW_COUNT();

    IF v_item_count = 0 THEN
        ROLLBACK;                         -- header without lines is meaningless
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'No valid prescription items parsed from JSON';
    END IF;

    COMMIT;
END$$

DROP PROCEDURE IF EXISTS sp_create_lab_order_result_workflow$$
CREATE PROCEDURE sp_create_lab_order_result_workflow(
    INOUT p_order_id     INT,
    IN    p_appointment_id INT,
    IN    p_test_id      INT,
    IN    p_priority     VARCHAR(10),
    IN    p_result_value VARCHAR(255),   -- NULL = only place the order
    IN    p_performed_by VARCHAR(100),
    IN    p_is_abnormal  BOOLEAN
)
MODIFIES SQL DATA
BEGIN
    DECLARE v_patient_id INT DEFAULT NULL;
    DECLARE v_doctor_id  INT DEFAULT NULL;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    SELECT patient_id, doctor_id INTO v_patient_id, v_doctor_id
      FROM appointments WHERE appointment_id = p_appointment_id;

    IF v_patient_id IS NULL THEN
        ROLLBACK;
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Appointment does not exist';
    END IF;

    INSERT INTO lab_orders (appointment_id, patient_id, doctor_id, test_id, priority, status)
    VALUES (p_appointment_id, v_patient_id, v_doctor_id, p_test_id,
            COALESCE(p_priority,'Routine'), 'Pending');

    SET p_order_id = LAST_INSERT_ID();

    IF p_result_value IS NOT NULL THEN
        -- The trigger trg_lab_result_ai_close flips the order to 'Completed'.
        INSERT INTO lab_results (order_id, result_value, performed_by, is_abnormal)
        VALUES (p_order_id, p_result_value, p_performed_by, COALESCE(p_is_abnormal, FALSE));
    END IF;

    COMMIT;
END$$

-- ============================================================================
-- MEMBER 3 — PROCEDURES
-- ============================================================================

DROP PROCEDURE IF EXISTS sp_create_bill_with_items$$
CREATE PROCEDURE sp_create_bill_with_items(
    INOUT p_bill_id        INT,
    IN    p_patient_id     INT,
    IN    p_appointment_id INT,
    IN    p_items_json     JSON,   -- [{"service_id":1,"quantity":2}, ...]
    IN    p_discount       DECIMAL(10,2),
    IN    p_tax_rate       DECIMAL(5,2)   -- e.g. 2.00 for 2%
)
MODIFIES SQL DATA
BEGIN
    DECLARE v_subtotal DECIMAL(12,2) DEFAULT 0.00;
    DECLARE v_tax      DECIMAL(12,2) DEFAULT 0.00;
    DECLARE v_total    DECIMAL(12,2) DEFAULT 0.00;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    IF p_items_json IS NULL OR JSON_LENGTH(p_items_json) = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'A bill must have at least one item';
    END IF;

    START TRANSACTION;

    INSERT INTO bills (patient_id, appointment_id, subtotal, discount, tax,
                       total_amount, paid_amount, balance_amount, status)
    VALUES (p_patient_id, p_appointment_id, 0, COALESCE(p_discount,0), 0, 0, 0, 0, 'Pending');

    SET p_bill_id = LAST_INSERT_ID();

    -- Price is taken from the services master, NOT from the caller: a client
    -- must never be able to invent its own price.
    INSERT INTO bill_items (bill_id, service_id, description, quantity, unit_price, amount)
    SELECT p_bill_id, s.service_id, s.service_name, j.quantity, s.price, j.quantity * s.price
    FROM JSON_TABLE(p_items_json, '$[*]' COLUMNS (
             service_id INT PATH '$.service_id',
             quantity   INT PATH '$.quantity'
         )) AS j
    JOIN services s ON s.service_id = j.service_id AND s.is_active = TRUE;

    IF ROW_COUNT() = 0 THEN
        ROLLBACK;
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'No active services matched the requested items';
    END IF;

    SET v_subtotal = fn_calculate_bill_subtotal(p_bill_id);
    SET v_tax      = ROUND((v_subtotal - COALESCE(p_discount,0)) * COALESCE(p_tax_rate,0) / 100, 2);
    SET v_total    = v_subtotal - COALESCE(p_discount,0) + v_tax;

    IF v_total < 0 THEN
        ROLLBACK;
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Discount is larger than the bill';
    END IF;

    UPDATE bills
       SET subtotal       = v_subtotal,
           tax            = v_tax,
           total_amount   = v_total,
           balance_amount = v_total          -- nothing paid yet
     WHERE bill_id = p_bill_id;

    COMMIT;
END$$

-- Thin wrapper: insert the payment FACT only. The trigger derives the header.
DROP PROCEDURE IF EXISTS sp_record_payment$$
CREATE PROCEDURE sp_record_payment(
    INOUT p_payment_id  INT,
    IN    p_bill_id     INT,
    IN    p_amount      DECIMAL(10,2),
    IN    p_method      VARCHAR(20),
    IN    p_reference   VARCHAR(50),
    IN    p_received_by VARCHAR(100)
)
MODIFIES SQL DATA
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;
    INSERT INTO payments (bill_id, amount, payment_method, reference_number, received_by)
    VALUES (p_bill_id, p_amount, p_method, p_reference, p_received_by);
    SET p_payment_id = LAST_INSERT_ID();
    COMMIT;
END$$

-- ----------------------------------------------------------------------------
-- MEMBER 3'S MAIN L9-L10 DEMONSTRATION.
-- Shows, in one routine: START TRANSACTION, pessimistic locking (FOR UPDATE),
-- a SAVEPOINT with a partial ROLLBACK TO, business validation, COMMIT, and
-- full ROLLBACK via the EXIT HANDLER.
--
-- Why FOR UPDATE is not optional here: read the balance, decide, then write.
-- Without the X-lock two cashiers both read balance = 1000, both accept a
-- 1000 payment, and the bill ends up paid 2000 -> LOST UPDATE.
-- ----------------------------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_process_complete_payment_transaction$$
CREATE PROCEDURE sp_process_complete_payment_transaction(
    IN  p_bill_id      INT,
    IN  p_amount       DECIMAL(10,2),
    IN  p_method       VARCHAR(20),
    IN  p_reference    VARCHAR(50),
    IN  p_received_by  VARCHAR(100),
    IN  p_apply_insurance BOOLEAN,
    OUT p_new_status   VARCHAR(20),
    OUT p_new_balance  DECIMAL(12,2)
)
MODIFIES SQL DATA
BEGIN
    DECLARE v_total    DECIMAL(12,2) DEFAULT NULL;
    DECLARE v_paid     DECIMAL(12,2) DEFAULT NULL;
    DECLARE v_balance  DECIMAL(12,2) DEFAULT NULL;
    DECLARE v_cover    DECIMAL(12,2) DEFAULT 0.00;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    IF p_amount IS NULL OR p_amount <= 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Payment amount must be greater than zero';
    END IF;

    START TRANSACTION;

    -- (1) X-LOCK the bill row. Every other session that reaches this line for
    --     the same bill_id now WAITS until we COMMIT or ROLLBACK.
    SELECT total_amount, paid_amount, (total_amount - paid_amount)
      INTO v_total, v_paid, v_balance
      FROM bills
     WHERE bill_id = p_bill_id
     FOR UPDATE;

    IF v_total IS NULL THEN
        ROLLBACK;
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Bill does not exist';
    END IF;

    -- (2) SAVEPOINT: the insurance credit is optional. If it turns out to be
    --     invalid we undo ONLY that part and still take the cash payment.
    SAVEPOINT before_insurance;

    IF p_apply_insurance THEN
        SET v_cover = fn_calculate_insurance_covered_amount(p_bill_id);
        IF v_cover > 0 AND v_cover <= v_balance THEN
            INSERT INTO payments (bill_id, amount, payment_method, reference_number, received_by, notes)
            VALUES (p_bill_id, v_cover, 'Insurance',
                    CONCAT('INS-', p_bill_id), p_received_by, 'Insurance settlement');
            SET v_balance = v_balance - v_cover;
        ELSE
            ROLLBACK TO SAVEPOINT before_insurance;   -- partial undo, txn stays open
            SET v_cover = 0.00;
        END IF;
    END IF;

    -- (3) Business rule: never let a bill be overpaid.
    IF p_amount > v_balance THEN
        ROLLBACK;
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Payment exceeds the outstanding balance';
    END IF;

    INSERT INTO payments (bill_id, amount, payment_method, reference_number, received_by)
    VALUES (p_bill_id, p_amount, p_method, p_reference, p_received_by);

    -- Bump the optimistic-locking version (used in the file 08 comparison)
    UPDATE bills SET row_version = row_version + 1 WHERE bill_id = p_bill_id;

    COMMIT;

    SELECT status, balance_amount INTO p_new_status, p_new_balance
      FROM bills WHERE bill_id = p_bill_id;
END$$

-- ============================================================================
-- MEMBER 4 — PROCEDURES
-- ============================================================================

DROP PROCEDURE IF EXISTS sp_receive_medicine_stock$$
CREATE PROCEDURE sp_receive_medicine_stock(
    INOUT p_batch_id      INT,
    IN    p_medicine_id   INT,
    IN    p_batch_number  VARCHAR(50),
    IN    p_quantity      INT,
    IN    p_manufacture   DATE,
    IN    p_expiry        DATE,
    IN    p_supplier      VARCHAR(100),
    IN    p_purchase_price DECIMAL(10,2),
    IN    p_performed_by  VARCHAR(100)
)
MODIFIES SQL DATA
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    IF p_quantity IS NULL OR p_quantity <= 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Received quantity must be positive';
    END IF;
    IF p_expiry <= CURDATE() THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Cannot receive stock that is already expired';
    END IF;

    START TRANSACTION;

    -- The batch starts EMPTY; the stock transaction below is what fills it.
    -- (Single-owner rule: quantity_available is written only by the trigger.)
    INSERT INTO inventory_batches (medicine_id, batch_number, quantity_received,
                                   quantity_available, manufacture_date, expiry_date,
                                   supplier_name, purchase_price)
    VALUES (p_medicine_id, p_batch_number, p_quantity, 0,
            p_manufacture, p_expiry, p_supplier, p_purchase_price);

    SET p_batch_id = LAST_INSERT_ID();

    INSERT INTO stock_transactions (batch_id, medicine_id, transaction_type,
                                    quantity, performed_by, notes)
    VALUES (p_batch_id, p_medicine_id, 'Receive', p_quantity, p_performed_by,
            CONCAT('GRN for batch ', p_batch_number));

    COMMIT;
END$$

-- ----------------------------------------------------------------------------
-- MEMBER 4'S MAIN L12-L13 DEMONSTRATION — FIFO dispensing.
-- Walks batches in expiry order, X-locking ONE batch row at a time with
-- SELECT ... FOR UPDATE, so two pharmacists dispensing the same drug queue up
-- instead of both reading the same quantity_available (lost update).
-- ----------------------------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_dispense_medicine$$
CREATE PROCEDURE sp_dispense_medicine(
    INOUT p_dispensation_id INT,
    IN    p_prescription_id INT,
    IN    p_medicine_id     INT,
    IN    p_quantity        INT,
    IN    p_dispensed_by    VARCHAR(100)
)
MODIFIES SQL DATA
BEGIN
    DECLARE v_patient_id INT DEFAULT NULL;
    DECLARE v_remaining  INT;
    DECLARE v_batch_id   INT;
    DECLARE v_avail      INT;
    DECLARE v_take       INT;
    DECLARE v_not_found  TINYINT DEFAULT 0;

    DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_not_found = 1;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    IF p_quantity IS NULL OR p_quantity <= 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Dispense quantity must be positive';
    END IF;

    SET v_remaining = p_quantity;

    START TRANSACTION;

    SELECT patient_id INTO v_patient_id
      FROM prescriptions WHERE prescription_id = p_prescription_id;

    IF v_patient_id IS NULL THEN
        ROLLBACK;
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Prescription does not exist';
    END IF;

    INSERT INTO pharmacy_dispensations (prescription_id, patient_id, dispensed_by,
                                        total_items, status)
    VALUES (p_prescription_id, v_patient_id, p_dispensed_by, 0, 'Completed');
    SET p_dispensation_id = LAST_INSERT_ID();

    fifo_loop: WHILE v_remaining > 0 DO
        SET v_not_found = 0;
        SET v_batch_id  = NULL;

        -- FIFO / FEFO: oldest usable expiry first. FOR UPDATE holds the X-lock
        -- on this batch row until COMMIT.
        SELECT batch_id, quantity_available
          INTO v_batch_id, v_avail
          FROM inventory_batches
         WHERE medicine_id = p_medicine_id
           AND quantity_available > 0
           AND expiry_date >= CURDATE()
         ORDER BY expiry_date, batch_id
         LIMIT 1
         FOR UPDATE;

        IF v_not_found = 1 OR v_batch_id IS NULL THEN
            ROLLBACK;      -- undoes the dispensation header too: all or nothing
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'INSUFFICIENT STOCK: not enough unexpired quantity';
        END IF;

        SET v_take = LEAST(v_avail, v_remaining);

        INSERT INTO stock_transactions (batch_id, medicine_id, transaction_type,
                                        quantity, performed_by, reference_id, notes)
        VALUES (v_batch_id, p_medicine_id, 'Dispense', v_take, p_dispensed_by,
                p_dispensation_id, 'Auto FIFO dispense');

        SET v_remaining = v_remaining - v_take;
    END WHILE fifo_loop;

    UPDATE pharmacy_dispensations
       SET total_items = p_quantity
     WHERE dispensation_id = p_dispensation_id;

    COMMIT;
END$$

DROP PROCEDURE IF EXISTS sp_record_stock_adjustment$$
CREATE PROCEDURE sp_record_stock_adjustment(
    IN p_batch_id     INT,
    IN p_quantity     INT,          -- always positive
    IN p_direction    VARCHAR(10),  -- 'ADD' or 'REMOVE'
    IN p_performed_by VARCHAR(100),
    IN p_notes        VARCHAR(255)
)
MODIFIES SQL DATA
BEGIN
    DECLARE v_medicine_id INT DEFAULT NULL;
    DECLARE v_avail       INT DEFAULT NULL;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    IF p_quantity IS NULL OR p_quantity <= 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Adjustment quantity must be positive';
    END IF;
    IF p_direction NOT IN ('ADD','REMOVE') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Direction must be ADD or REMOVE';
    END IF;

    START TRANSACTION;

    SELECT medicine_id, quantity_available INTO v_medicine_id, v_avail
      FROM inventory_batches WHERE batch_id = p_batch_id FOR UPDATE;

    IF v_medicine_id IS NULL THEN
        ROLLBACK;
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Batch does not exist';
    END IF;

    IF p_direction = 'REMOVE' AND v_avail < p_quantity THEN
        ROLLBACK;
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Adjustment would make stock negative';
    END IF;

    INSERT INTO stock_transactions (batch_id, medicine_id, transaction_type,
                                    quantity, performed_by, notes)
    VALUES (p_batch_id, v_medicine_id,
            IF(p_direction = 'ADD', 'Return', 'Adjustment'),
            p_quantity, p_performed_by, p_notes);

    COMMIT;
END$$

-- ============================================================================
-- MEMBER 5 — PROCEDURES
-- ============================================================================

DROP PROCEDURE IF EXISTS sp_create_user_with_role$$
CREATE PROCEDURE sp_create_user_with_role(
    INOUT p_user_id     INT,
    IN    p_username    VARCHAR(50),
    IN    p_password    VARCHAR(255),   -- plaintext in, hashed here
    IN    p_email       VARCHAR(100),
    IN    p_full_name   VARCHAR(100),
    IN    p_phone       VARCHAR(20),
    IN    p_role_name   VARCHAR(50),
    IN    p_assigned_by VARCHAR(100)
)
MODIFIES SQL DATA
BEGIN
    DECLARE v_role_id INT DEFAULT NULL;

    DECLARE EXIT HANDLER FOR 1062
    BEGIN
        ROLLBACK;
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Username or email already exists';
    END;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    SELECT role_id INTO v_role_id FROM roles WHERE role_name = p_role_name;
    IF v_role_id IS NULL THEN
        ROLLBACK;
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Role does not exist';
    END IF;

    -- Never store a plaintext password. SHA2 here keeps the demo self-contained;
    -- a production system would use bcrypt/argon2 in the application layer.
    INSERT INTO users (username, password_hash, email, full_name, phone)
    VALUES (p_username, SHA2(p_password, 256), p_email, p_full_name, p_phone);

    SET p_user_id = LAST_INSERT_ID();

    INSERT INTO user_roles (user_id, role_id, assigned_by)
    VALUES (p_user_id, v_role_id, p_assigned_by);

    COMMIT;
END$$

DROP PROCEDURE IF EXISTS sp_assign_revoke_role_permission$$
CREATE PROCEDURE sp_assign_revoke_role_permission(
    IN p_role_id       INT,
    IN p_permission_id INT,
    IN p_action        VARCHAR(10),   -- 'ASSIGN' | 'REVOKE'
    IN p_actor_user_id INT
)
MODIFIES SQL DATA
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    IF p_action NOT IN ('ASSIGN','REVOKE') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Invalid action: use ASSIGN or REVOKE';
    END IF;

    -- Makes the audit trigger able to record WHO did it.
    SET @app_user_id = p_actor_user_id;

    START TRANSACTION;

    IF p_action = 'ASSIGN' THEN
        -- Idempotent thanks to UNIQUE(role_id, permission_id)
        INSERT IGNORE INTO role_permissions (role_id, permission_id)
        VALUES (p_role_id, p_permission_id);
    ELSE
        DELETE FROM role_permissions
         WHERE role_id = p_role_id AND permission_id = p_permission_id;

        INSERT INTO audit_logs (user_id, entity_name, entity_id, action, old_value)
        VALUES (p_actor_user_id, 'role_permissions', p_role_id, 'DELETE',
                CONCAT('revoked permission_id=', p_permission_id));
    END IF;

    COMMIT;
END$$

DROP PROCEDURE IF EXISTS sp_generate_audit_report$$
CREATE PROCEDURE sp_generate_audit_report(
    IN p_from        DATETIME,
    IN p_to          DATETIME,
    IN p_entity_name VARCHAR(50)    -- NULL = all entities
)
READS SQL DATA
BEGIN
    SELECT al.entity_name,
           al.action,
           COUNT(*)                          AS event_count,
           COUNT(DISTINCT al.user_id)        AS distinct_users,
           MIN(al.created_at)                AS first_event,
           MAX(al.created_at)                AS last_event
    FROM audit_logs al
    WHERE al.created_at >= p_from
      AND al.created_at <  p_to                   -- half-open: index friendly
      AND (p_entity_name IS NULL OR al.entity_name = p_entity_name)
    GROUP BY al.entity_name, al.action
    ORDER BY al.entity_name, event_count DESC;
END$$

-- ============================================================================
-- UTILITY — used by L7/L8 (pre-aggregation beats the slow month-end report)
-- ============================================================================
DROP PROCEDURE IF EXISTS sp_refresh_monthly_revenue$$
CREATE PROCEDURE sp_refresh_monthly_revenue(IN p_ym CHAR(7))
MODIFIES SQL DATA
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    DELETE FROM monthly_revenue_summary WHERE ym_key = p_ym;

    INSERT INTO monthly_revenue_summary (ym_key, department_id, bill_count,
                                         total_billed, total_paid)
    SELECT p_ym,
           d.department_id,
           COUNT(DISTINCT b.bill_id),
           SUM(b.total_amount),
           SUM(b.paid_amount)
    FROM bills b
    JOIN appointments a ON a.appointment_id = b.appointment_id
    JOIN doctors      d ON d.doctor_id      = a.doctor_id
    WHERE b.bill_date >= STR_TO_DATE(CONCAT(p_ym,'-01'), '%Y-%m-%d')
      AND b.bill_date <  STR_TO_DATE(CONCAT(p_ym,'-01'), '%Y-%m-%d') + INTERVAL 1 MONTH
      AND b.status <> 'Cancelled'
    GROUP BY d.department_id;

    COMMIT;
END$$

DELIMITER ;

-- ============================================================================
-- VERIFY
-- ============================================================================
SELECT ROUTINE_NAME, SQL_DATA_ACCESS
FROM information_schema.ROUTINES
WHERE ROUTINE_SCHEMA = 'hospital_management' AND ROUTINE_TYPE = 'PROCEDURE'
ORDER BY ROUTINE_NAME;

-- END OF FILE 04


-- ############################################################################
-- ##  STAGE 5  --  05_triggers.sql
