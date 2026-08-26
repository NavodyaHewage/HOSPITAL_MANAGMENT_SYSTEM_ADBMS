-- ############################################################################
-- ############################################################################
--
--        HOSPITAL / CLINIC MANAGEMENT SYSTEM  —  MASTER BUILD SCRIPT
--        Advanced Database Systems group project (5 members)
--
--        THIS ONE FILE BUILDS THE ENTIRE DATABASE, TOP TO BOTTOM.
--        Open it in MySQL Workbench and press Execute (Ctrl+Shift+Enter) once.
--
-- ############################################################################
-- ############################################################################
--
--  BUILD FLOW (the order is not optional — each stage depends on the one above)
--
--    STAGE 1  SCHEMA        25 tables, PK/FK/UNIQUE/CHECK, 15 secondary indexes
--    STAGE 2  SEED DATA     ~50k appointments + ~50k audit rows, so that
--                           EXPLAIN in the demo files shows a real difference
--    STAGE 3  FUNCTIONS     15 functions  (3 per member)
--             VIEWS         15 views      (3 per member)
--    STAGE 4  PROCEDURES    15 procedures (3 per member) + 1 utility
--    STAGE 5  TRIGGERS      15 triggers   (3 per member)
--    STAGE 6  VERIFICATION  counts every object and proves the data is consistent
--
--  WHY SEED DATA COMES BEFORE TRIGGERS:
--    Loading 200,000 rows through row-level triggers is slow and would flood
--    audit_logs with meaningless rows. The seed computes every derived column
--    (bills.paid_amount, inventory_batches.quantity_available, ...) by hand,
--    and STAGE 6 proves those values match what the triggers would have
--    produced. From the first live INSERT onwards, the triggers take over.
--
--  AFTER THIS FILE, RUN THE THREE DEMO FILES **BLOCK BY BLOCK** (not whole):
--    06_transactions_L9_L10.sql              L9-L10  10 transactions
--    07_optimization_L1_L8.sql               L1-L8   file org, indexing, EXPLAIN
--    08_serializability_concurrency_L11_L13  L11-L13 serializability, locking
--
--  REQUIREMENTS
--    MySQL 8.0.16 or newer (CHECK constraints, window functions, CTEs,
--    generated columns, EXPLAIN ANALYZE, SKIP LOCKED / NOWAIT).
--
--  RUN TIME: roughly 1-3 minutes, almost all of it STAGE 2.
--
--  WARNING: STAGE 1 runs DROP DATABASE IF EXISTS hospital_management.
--           Re-running this file wipes and rebuilds everything. That is
--           intentional - you can always get back to a clean demo state.
--
-- ############################################################################

SELECT VERSION() AS mysql_version,
       CASE WHEN VERSION() >= "8.0.16" THEN "OK - proceed"
            ELSE "TOO OLD - CHECK constraints and window functions will fail"
       END AS version_check;



-- ############################################################################
-- ##  STAGE 1  --  01_schema.sql
-- ############################################################################

-- ============================================================================
-- HOSPITAL / CLINIC MANAGEMENT SYSTEM
-- FILE 01 of 08 : SCHEMA (DDL)
-- Engine: InnoDB (REQUIRED - MyISAM has no transactions, no row locks, no FKs)
-- Run order: 01 -> 02 -> 03 -> 04 -> 05 -> 06 -> 07 -> 08
-- ============================================================================
-- WHY InnoDB (say this in viva, L9-L13 depend on it):
--   * ACID transactions (COMMIT / ROLLBACK / SAVEPOINT)
--   * Row-level locking + MVCC  -> concurrency control demos work
--   * Foreign keys enforced     -> referential integrity / consistency
--   * Clustered B+Tree index on PK -> file organization discussion (L1-L3)
-- ============================================================================

DROP DATABASE IF EXISTS hospital_management;
CREATE DATABASE hospital_management
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_0900_ai_ci;
USE hospital_management;

SET SESSION sql_mode = 'STRICT_ALL_TABLES,NO_ENGINE_SUBSTITUTION';
SET SESSION cte_max_recursion_depth = 200000;   -- needed by 02_seed_data.sql

-- ============================================================================
-- MEMBER 5 -- SECURITY & AUDITING  (created FIRST: audit_logs is referenced
--             by triggers belonging to every other member)
-- ============================================================================

CREATE TABLE users (
    user_id         INT           PRIMARY KEY AUTO_INCREMENT,
    username        VARCHAR(50)   NOT NULL,
    password_hash   VARCHAR(255)  NOT NULL,
    email           VARCHAR(100),
    full_name       VARCHAR(100)  NOT NULL,
    phone           VARCHAR(20),
    is_active       BOOLEAN       NOT NULL DEFAULT TRUE,
    last_login      DATETIME      NULL,
    created_at      DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at      DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP
                                  ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT uq_users_username UNIQUE (username),
    CONSTRAINT uq_users_email    UNIQUE (email)
) ENGINE=InnoDB;

CREATE TABLE roles (
    role_id     INT          PRIMARY KEY AUTO_INCREMENT,
    role_name   VARCHAR(50)  NOT NULL,
    description TEXT,
    created_at  DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_roles_name UNIQUE (role_name)
) ENGINE=InnoDB;

CREATE TABLE permissions (
    permission_id   INT          PRIMARY KEY AUTO_INCREMENT,
    permission_name VARCHAR(50)  NOT NULL,
    module          VARCHAR(50),
    description     TEXT,
    created_at      DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_permissions_name UNIQUE (permission_name)
) ENGINE=InnoDB;

-- FIX vs original: UNIQUE(user_id, role_id) added.
-- Without it the same role can be granted twice -> ASSIGN/REVOKE becomes
-- non-idempotent and the L9-L10 role transaction cannot be replayed safely.
CREATE TABLE user_roles (
    user_role_id  INT       PRIMARY KEY AUTO_INCREMENT,
    user_id       INT       NOT NULL,
    role_id       INT       NOT NULL,
    assigned_date DATETIME  NOT NULL DEFAULT CURRENT_TIMESTAMP,
    assigned_by   VARCHAR(100),
    CONSTRAINT uq_user_roles UNIQUE (user_id, role_id),
    CONSTRAINT fk_user_roles_user FOREIGN KEY (user_id)
        REFERENCES users(user_id) ON DELETE CASCADE,
    CONSTRAINT fk_user_roles_role FOREIGN KEY (role_id)
        REFERENCES roles(role_id) ON DELETE RESTRICT
) ENGINE=InnoDB;

CREATE TABLE role_permissions (
    role_permission_id INT      PRIMARY KEY AUTO_INCREMENT,
    role_id            INT      NOT NULL,
    permission_id      INT      NOT NULL,
    assigned_date      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_role_permissions UNIQUE (role_id, permission_id),
    CONSTRAINT fk_rp_role FOREIGN KEY (role_id)
        REFERENCES roles(role_id) ON DELETE CASCADE,
    CONSTRAINT fk_rp_permission FOREIGN KEY (permission_id)
        REFERENCES permissions(permission_id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE audit_logs (
    log_id      INT          PRIMARY KEY AUTO_INCREMENT,
    user_id     INT          NULL,
    entity_name VARCHAR(50)  NOT NULL,
    entity_id   INT          NULL,
    action      ENUM('INSERT','UPDATE','DELETE','LOGIN','LOGOUT') NOT NULL,
    old_value   TEXT,
    new_value   TEXT,
    ip_address  VARCHAR(45),
    created_at  DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_audit_user FOREIGN KEY (user_id)
        REFERENCES users(user_id) ON DELETE SET NULL
) ENGINE=InnoDB;

-- ============================================================================
-- MEMBER 1 -- PATIENT & APPOINTMENT
-- ============================================================================

CREATE TABLE departments (
    department_id   INT          PRIMARY KEY AUTO_INCREMENT,
    department_name VARCHAR(100) NOT NULL,
    description     TEXT,
    location        VARCHAR(100),
    contact_number  VARCHAR(20),
    is_active       BOOLEAN      NOT NULL DEFAULT TRUE,
    created_at      DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_department_name UNIQUE (department_name)
) ENGINE=InnoDB;

CREATE TABLE doctors (
    doctor_id        INT           PRIMARY KEY AUTO_INCREMENT,
    department_id    INT           NOT NULL,
    first_name       VARCHAR(50)   NOT NULL,
    last_name        VARCHAR(50)   NOT NULL,
    specialization   VARCHAR(100),
    qualification    VARCHAR(150),
    license_number   VARCHAR(50)   NOT NULL,
    phone            VARCHAR(20),
    email            VARCHAR(100),
    consultation_fee DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    is_active        BOOLEAN       NOT NULL DEFAULT TRUE,
    created_at       DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at       DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP
                                   ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT uq_doctor_license UNIQUE (license_number),
    CONSTRAINT uq_doctor_email   UNIQUE (email),
    CONSTRAINT chk_doctor_fee    CHECK (consultation_fee >= 0),
    CONSTRAINT fk_doctor_department FOREIGN KEY (department_id)
        REFERENCES departments(department_id) ON DELETE RESTRICT
) ENGINE=InnoDB;

CREATE TABLE patients (
    patient_id              INT          PRIMARY KEY AUTO_INCREMENT,
    first_name              VARCHAR(50)  NOT NULL,
    last_name               VARCHAR(50)  NOT NULL,
    date_of_birth           DATE         NOT NULL,
    gender                  ENUM('Male','Female','Other') NOT NULL,
    blood_group             VARCHAR(5),
    phone                   VARCHAR(20)  NOT NULL,
    email                   VARCHAR(100),
    address                 VARCHAR(255),
    emergency_contact_name  VARCHAR(100),
    emergency_contact_phone VARCHAR(20),
    national_id             VARCHAR(30),
    registered_date         DATE         NOT NULL DEFAULT (CURRENT_DATE),
    is_active               BOOLEAN      NOT NULL DEFAULT TRUE,
    created_at              DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at              DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP
                                         ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT uq_patient_nic UNIQUE (national_id)
) ENGINE=InnoDB;

-- ----------------------------------------------------------------------------
-- KEY DESIGN POINT FOR L12-L13 (concurrency control)
-- ----------------------------------------------------------------------------
-- active_slot_key is a STORED GENERATED COLUMN. It is non-NULL only while the
-- appointment is live (Scheduled / Confirmed). A UNIQUE index on it means the
-- ENGINE itself refuses a double booking, even if two sessions race.
-- Cancelled / Completed / No-Show rows evaluate to NULL, and MySQL allows
-- many NULLs in a UNIQUE index -> a cancelled slot can be re-booked.
-- This is the "declarative" half of the double-booking defence; the
-- "procedural" half (SELECT ... FOR UPDATE) is demonstrated in 06.
-- ----------------------------------------------------------------------------
CREATE TABLE appointments (
    appointment_id   INT   PRIMARY KEY AUTO_INCREMENT,
    patient_id       INT   NOT NULL,
    doctor_id        INT   NOT NULL,
    appointment_date DATE  NOT NULL,
    appointment_time TIME  NOT NULL,
    status ENUM('Scheduled','Confirmed','Completed','Cancelled','No-Show')
                     NOT NULL DEFAULT 'Scheduled',
    reason           VARCHAR(255),
    notes            TEXT,
    created_at       DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at       DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
                              ON UPDATE CURRENT_TIMESTAMP,
    active_slot_key  VARCHAR(60)
        GENERATED ALWAYS AS (
            CASE WHEN status IN ('Scheduled','Confirmed')
                 THEN CONCAT(doctor_id,'|',appointment_date,'|',appointment_time)
                 ELSE NULL END
        ) STORED,
    CONSTRAINT uq_active_slot UNIQUE (active_slot_key),
    CONSTRAINT fk_appt_patient FOREIGN KEY (patient_id)
        REFERENCES patients(patient_id) ON DELETE RESTRICT,
    CONSTRAINT fk_appt_doctor FOREIGN KEY (doctor_id)
        REFERENCES doctors(doctor_id) ON DELETE RESTRICT
) ENGINE=InnoDB;

-- ============================================================================
-- MEMBER 4 -- INVENTORY & PHARMACY
-- (medicines is created before prescription_items so the FK is inline, not a
--  later ALTER TABLE as in the original file)
-- ============================================================================

CREATE TABLE medicines (
    medicine_id     INT           PRIMARY KEY AUTO_INCREMENT,
    medicine_name   VARCHAR(100)  NOT NULL,
    generic_name    VARCHAR(100),
    category        VARCHAR(50),
    manufacturer    VARCHAR(100),
    unit_of_measure VARCHAR(20),
    reorder_level   INT           NOT NULL DEFAULT 10,
    unit_price      DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    is_active       BOOLEAN       NOT NULL DEFAULT TRUE,
    CONSTRAINT chk_medicine_reorder CHECK (reorder_level >= 0),
    CONSTRAINT chk_medicine_price   CHECK (unit_price   >= 0)
) ENGINE=InnoDB;

-- FIX vs original: UNIQUE(medicine_id, batch_number) - the same batch number
-- must not be receivable twice for the same drug.
CREATE TABLE inventory_batches (
    batch_id           INT           PRIMARY KEY AUTO_INCREMENT,
    medicine_id        INT           NOT NULL,
    batch_number       VARCHAR(50)   NOT NULL,
    quantity_received  INT           NOT NULL,
    quantity_available INT           NOT NULL,
    manufacture_date   DATE,
    expiry_date        DATE          NOT NULL,
    supplier_name      VARCHAR(100),
    purchase_price     DECIMAL(10,2),
    received_date      DATE          NOT NULL DEFAULT (CURRENT_DATE),
    created_at         DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_batch UNIQUE (medicine_id, batch_number),
    CONSTRAINT chk_batch_qty_recv  CHECK (quantity_received  >= 0),
    CONSTRAINT chk_batch_qty_avail CHECK (quantity_available >= 0),
    CONSTRAINT fk_batch_medicine FOREIGN KEY (medicine_id)
        REFERENCES medicines(medicine_id) ON DELETE RESTRICT
) ENGINE=InnoDB;

CREATE TABLE stock_transactions (
    transaction_id   INT      PRIMARY KEY AUTO_INCREMENT,
    batch_id         INT      NOT NULL,
    medicine_id      INT      NOT NULL,
    transaction_type ENUM('Receive','Dispense','Adjustment','Return') NOT NULL,
    quantity         INT      NOT NULL,   -- always POSITIVE; sign comes from type
    transaction_date DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    performed_by     VARCHAR(100),
    reference_id     INT,
    notes            TEXT,
    created_at       DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_stock_qty CHECK (quantity > 0),
    CONSTRAINT fk_stock_batch FOREIGN KEY (batch_id)
        REFERENCES inventory_batches(batch_id) ON DELETE RESTRICT,
    CONSTRAINT fk_stock_medicine FOREIGN KEY (medicine_id)
        REFERENCES medicines(medicine_id) ON DELETE RESTRICT
) ENGINE=InnoDB;

-- ============================================================================
-- MEMBER 2 -- CLINICAL RECORDS
-- ============================================================================

CREATE TABLE consultations (
    consultation_id   INT      PRIMARY KEY AUTO_INCREMENT,
    appointment_id    INT      NOT NULL,
    patient_id        INT      NOT NULL,
    doctor_id         INT      NOT NULL,
    consultation_date DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    chief_complaint   VARCHAR(255),
    diagnosis         TEXT,
    symptoms          TEXT,
    treatment_plan    TEXT,
    notes             TEXT,
    follow_up_date    DATE,
    created_at        DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_consultation_appt UNIQUE (appointment_id),  -- 1 appt = 1 consult
    CONSTRAINT fk_cons_appt FOREIGN KEY (appointment_id)
        REFERENCES appointments(appointment_id) ON DELETE RESTRICT,
    CONSTRAINT fk_cons_patient FOREIGN KEY (patient_id)
        REFERENCES patients(patient_id) ON DELETE RESTRICT,
    CONSTRAINT fk_cons_doctor FOREIGN KEY (doctor_id)
        REFERENCES doctors(doctor_id) ON DELETE RESTRICT
) ENGINE=InnoDB;

CREATE TABLE prescriptions (
    prescription_id   INT      PRIMARY KEY AUTO_INCREMENT,
    consultation_id   INT      NOT NULL,
    appointment_id    INT      NOT NULL,
    patient_id        INT      NOT NULL,
    doctor_id         INT      NOT NULL,
    prescription_date DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    status ENUM('Active','Completed','Cancelled') NOT NULL DEFAULT 'Active',
    notes             TEXT,
    created_at        DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_pres_consultation FOREIGN KEY (consultation_id)
        REFERENCES consultations(consultation_id) ON DELETE RESTRICT,
    CONSTRAINT fk_pres_appt FOREIGN KEY (appointment_id)
        REFERENCES appointments(appointment_id) ON DELETE RESTRICT,
    CONSTRAINT fk_pres_patient FOREIGN KEY (patient_id)
        REFERENCES patients(patient_id) ON DELETE RESTRICT,
    CONSTRAINT fk_pres_doctor FOREIGN KEY (doctor_id)
        REFERENCES doctors(doctor_id) ON DELETE RESTRICT
) ENGINE=InnoDB;

CREATE TABLE prescription_items (
    item_id         INT PRIMARY KEY AUTO_INCREMENT,
    prescription_id INT NOT NULL,
    medicine_id     INT NOT NULL,
    dosage          VARCHAR(50),
    frequency       VARCHAR(50),
    duration_days   INT,
    quantity        INT NOT NULL,
    instructions    VARCHAR(255),
    created_at      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_pres_item_qty CHECK (quantity > 0),
    CONSTRAINT fk_pi_prescription FOREIGN KEY (prescription_id)
        REFERENCES prescriptions(prescription_id) ON DELETE CASCADE,
    CONSTRAINT fk_pi_medicine FOREIGN KEY (medicine_id)
        REFERENCES medicines(medicine_id) ON DELETE RESTRICT
) ENGINE=InnoDB;

CREATE TABLE lab_tests (
    test_id       INT           PRIMARY KEY AUTO_INCREMENT,
    test_name     VARCHAR(100)  NOT NULL,
    test_category VARCHAR(50),
    description   TEXT,
    normal_range  VARCHAR(100),
    unit          VARCHAR(20),
    price         DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    is_active     BOOLEAN       NOT NULL DEFAULT TRUE,
    CONSTRAINT uq_lab_test_name UNIQUE (test_name),
    CONSTRAINT chk_lab_price CHECK (price >= 0)
) ENGINE=InnoDB;

CREATE TABLE lab_orders (
    order_id       INT      PRIMARY KEY AUTO_INCREMENT,
    appointment_id INT      NOT NULL,
    patient_id     INT      NOT NULL,
    doctor_id      INT      NOT NULL,
    test_id        INT      NOT NULL,
    order_date     DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    priority ENUM('Routine','Urgent','Stat')                   NOT NULL DEFAULT 'Routine',
    status   ENUM('Pending','In-Progress','Completed','Cancelled') NOT NULL DEFAULT 'Pending',
    notes      TEXT,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_lo_appt FOREIGN KEY (appointment_id)
        REFERENCES appointments(appointment_id) ON DELETE RESTRICT,
    CONSTRAINT fk_lo_patient FOREIGN KEY (patient_id)
        REFERENCES patients(patient_id) ON DELETE RESTRICT,
    CONSTRAINT fk_lo_doctor FOREIGN KEY (doctor_id)
        REFERENCES doctors(doctor_id) ON DELETE RESTRICT,
    CONSTRAINT fk_lo_test FOREIGN KEY (test_id)
        REFERENCES lab_tests(test_id) ON DELETE RESTRICT
) ENGINE=InnoDB;

CREATE TABLE lab_results (
    result_id    INT          PRIMARY KEY AUTO_INCREMENT,
    order_id     INT          NOT NULL,
    result_value VARCHAR(255),
    result_date  DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    performed_by VARCHAR(100),
    remarks      TEXT,
    is_abnormal  BOOLEAN      NOT NULL DEFAULT FALSE,
    created_at   DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_lab_result_order UNIQUE (order_id),  -- 1 order = 1 result
    CONSTRAINT fk_lr_order FOREIGN KEY (order_id)
        REFERENCES lab_orders(order_id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE pharmacy_dispensations (
    dispensation_id INT      PRIMARY KEY AUTO_INCREMENT,
    prescription_id INT      NOT NULL,
    patient_id      INT      NOT NULL,
    dispensed_date  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    dispensed_by    VARCHAR(100),
    total_items     INT      NOT NULL DEFAULT 0,
    status ENUM('Completed','Partial') NOT NULL DEFAULT 'Completed',
    notes           TEXT,
    created_at      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_pd_prescription FOREIGN KEY (prescription_id)
        REFERENCES prescriptions(prescription_id) ON DELETE RESTRICT,
    CONSTRAINT fk_pd_patient FOREIGN KEY (patient_id)
        REFERENCES patients(patient_id) ON DELETE RESTRICT
) ENGINE=InnoDB;

-- ============================================================================
-- MEMBER 3 -- BILLING & PAYMENTS
-- ============================================================================

CREATE TABLE services (
    service_id       INT           PRIMARY KEY AUTO_INCREMENT,
    service_name     VARCHAR(100)  NOT NULL,
    service_category VARCHAR(50),
    description      TEXT,
    price            DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    is_active        BOOLEAN       NOT NULL DEFAULT TRUE,
    CONSTRAINT uq_service_name UNIQUE (service_name),
    CONSTRAINT chk_service_price CHECK (price >= 0)
) ENGINE=InnoDB;

CREATE TABLE insurance_profiles (
    insurance_id        INT           PRIMARY KEY AUTO_INCREMENT,
    patient_id          INT           NOT NULL,
    provider_name       VARCHAR(100)  NOT NULL,
    policy_number       VARCHAR(50)   NOT NULL,
    coverage_percentage DECIMAL(5,2)  NOT NULL DEFAULT 0.00,
    valid_from          DATE          NOT NULL,
    valid_to            DATE,
    is_active           BOOLEAN       NOT NULL DEFAULT TRUE,
    CONSTRAINT uq_policy UNIQUE (provider_name, policy_number),
    CONSTRAINT chk_coverage CHECK (coverage_percentage BETWEEN 0 AND 100),
    CONSTRAINT fk_ins_patient FOREIGN KEY (patient_id)
        REFERENCES patients(patient_id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE bills (
    bill_id        INT           PRIMARY KEY AUTO_INCREMENT,
    patient_id     INT           NOT NULL,
    appointment_id INT           NULL,
    bill_date      DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    subtotal       DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    discount       DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    tax            DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    total_amount   DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    paid_amount    DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    balance_amount DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    status ENUM('Pending','Partial','Paid','Cancelled') NOT NULL DEFAULT 'Pending',
    created_at     DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at     DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP
                                 ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT chk_bill_amounts CHECK (
        subtotal >= 0 AND discount >= 0 AND tax >= 0
        AND total_amount >= 0 AND paid_amount >= 0
    ),
    CONSTRAINT fk_bill_patient FOREIGN KEY (patient_id)
        REFERENCES patients(patient_id) ON DELETE RESTRICT,
    CONSTRAINT fk_bill_appt FOREIGN KEY (appointment_id)
        REFERENCES appointments(appointment_id) ON DELETE SET NULL
) ENGINE=InnoDB;

CREATE TABLE bill_items (
    bill_item_id INT           PRIMARY KEY AUTO_INCREMENT,
    bill_id      INT           NOT NULL,
    service_id   INT           NOT NULL,
    description  VARCHAR(255),
    quantity     INT           NOT NULL DEFAULT 1,
    unit_price   DECIMAL(10,2) NOT NULL,
    amount       DECIMAL(10,2) NOT NULL,
    created_at   DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_bill_item CHECK (quantity > 0 AND unit_price >= 0 AND amount >= 0),
    CONSTRAINT fk_bi_bill FOREIGN KEY (bill_id)
        REFERENCES bills(bill_id) ON DELETE CASCADE,
    CONSTRAINT fk_bi_service FOREIGN KEY (service_id)
        REFERENCES services(service_id) ON DELETE RESTRICT
) ENGINE=InnoDB;

CREATE TABLE payments (
    payment_id       INT           PRIMARY KEY AUTO_INCREMENT,
    bill_id          INT           NOT NULL,
    payment_date     DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    amount           DECIMAL(10,2) NOT NULL,
    payment_method   ENUM('Cash','Card','Insurance','Bank Transfer') NOT NULL,
    reference_number VARCHAR(50),
    received_by      VARCHAR(100),
    notes            TEXT,
    created_at       DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_payment_amount CHECK (amount > 0),
    CONSTRAINT fk_pay_bill FOREIGN KEY (bill_id)
        REFERENCES bills(bill_id) ON DELETE RESTRICT
) ENGINE=InnoDB;

-- ============================================================================
-- SECONDARY INDEXES  (L4)  -- 3 per member, exactly as assigned
-- Note: FK columns already get an automatic index from InnoDB. The indexes
-- below are the CHOSEN composite/covering indexes we defend in the viva.
-- ============================================================================

-- MEMBER 1
CREATE INDEX idx_appointments_doctor_datetime
    ON appointments (doctor_id, appointment_date, appointment_time);
CREATE INDEX idx_appointments_patient_status
    ON appointments (patient_id, status);
CREATE INDEX idx_doctors_department_active
    ON doctors (department_id, is_active);

-- MEMBER 2
CREATE INDEX idx_lab_orders_appointment_status
    ON lab_orders (appointment_id, status);
CREATE INDEX idx_lab_orders_status_priority
    ON lab_orders (status, priority);
CREATE INDEX idx_prescriptions_appointment_date
    ON prescriptions (appointment_id, prescription_date);

-- MEMBER 3
CREATE INDEX idx_payments_bill_date
    ON payments (bill_id, payment_date);
CREATE INDEX idx_bills_patient_status
    ON bills (patient_id, status);
CREATE INDEX idx_bill_items_bill_service
    ON bill_items (bill_id, service_id);

-- MEMBER 4
CREATE INDEX idx_inventory_batches_expiry
    ON inventory_batches (expiry_date);
CREATE INDEX idx_inventory_batches_medicine_expiry
    ON inventory_batches (medicine_id, expiry_date);
CREATE INDEX idx_stock_transactions_batch_date
    ON stock_transactions (batch_id, transaction_date);

-- MEMBER 5
CREATE INDEX idx_audit_logs_created_at
    ON audit_logs (created_at);
CREATE INDEX idx_audit_logs_entity_action
    ON audit_logs (entity_name, action);
CREATE INDEX idx_users_active_username
    ON users (is_active, username);

-- ============================================================================
-- SUPPORT OBJECTS FOR THE ADVANCED LESSONS
-- ============================================================================

-- L12-L13: optimistic locking (version column) on the hottest row in the DB.
ALTER TABLE bills
    ADD COLUMN row_version INT NOT NULL DEFAULT 0 AFTER status;

-- THE invariant Member 3 defends in L9-L13: a bill can never be overpaid.
-- Two concurrent payments that each individually fit inside the balance can
-- TOGETHER break this -> that is the lost-update demo in file 08.
ALTER TABLE bills
    ADD CONSTRAINT chk_bill_no_overpay CHECK (paid_amount <= total_amount);

-- L11: we physically record the interleaved schedule so the precedence graph
-- shown in the viva is generated FROM REAL EXECUTION, not drawn by hand.
CREATE TABLE txn_schedule_log (
    seq_no     INT          PRIMARY KEY AUTO_INCREMENT,
    txn_name   VARCHAR(10)  NOT NULL,      -- T1 / T2 / T3
    operation  ENUM('READ','WRITE','COMMIT','ABORT') NOT NULL,
    data_item  VARCHAR(30),                -- logical item: A / B
    value_seen DECIMAL(14,2),
    note       VARCHAR(120),
    logged_at  DATETIME(6)  NOT NULL DEFAULT CURRENT_TIMESTAMP(6)
) ENGINE=InnoDB;

-- L7-L8: materialised (pre-aggregated) summary used to beat the slow
-- month-end report. Refreshed by sp_refresh_monthly_revenue.
CREATE TABLE monthly_revenue_summary (
    ym_key        CHAR(7)       NOT NULL,     -- '2026-08'
    department_id INT           NOT NULL,
    bill_count    INT           NOT NULL,
    total_billed  DECIMAL(14,2) NOT NULL,
    total_paid    DECIMAL(14,2) NOT NULL,
    refreshed_at  DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (ym_key, department_id),
    CONSTRAINT fk_mrs_dept FOREIGN KEY (department_id)
        REFERENCES departments(department_id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- ============================================================================
-- VERIFY
-- ============================================================================
SELECT TABLE_NAME, ENGINE, TABLE_COLLATION
FROM information_schema.TABLES
WHERE TABLE_SCHEMA = 'hospital_management'
ORDER BY TABLE_NAME;

-- END OF FILE 01


-- ############################################################################
-- ##  STAGE 2  --  02_seed_data.sql
-- ############################################################################

-- ============================================================================
--  FILE 02 of 08 : SEED DATA
-- ============================================================================
--  WHY THIS FILE MATTERS FOR THE VIVA
--  An index demo on 10 rows proves nothing - MySQL will full-scan 10 rows and
--  be faster than using the index. We load ~50,000 appointments, ~50,000 audit
--  rows etc. so that EXPLAIN in file 07 shows a REAL difference
--  (type=ALL, rows=50000  ->  type=ref, rows=12).
--
--  IMPORTANT: this file runs BEFORE triggers are created (file 05). That is
--  deliberate - loading 200k rows through row-level triggers is slow and would
--  pollute audit_logs. All derived columns are computed correctly here by hand.
-- ============================================================================

USE hospital_management;
SET SESSION cte_max_recursion_depth = 200000;
SET SESSION sql_mode = 'STRICT_ALL_TABLES,NO_ENGINE_SUBSTITUTION';
SET autocommit = 1;

-- ----------------------------------------------------------------------------
-- 0. NUMBERS HELPER TABLE (a "tally table")
--    One recursive CTE, then every bulk INSERT below is a simple, fast join.
-- ----------------------------------------------------------------------------
DROP TABLE IF EXISTS seq_numbers;
CREATE TABLE seq_numbers (n INT PRIMARY KEY) ENGINE=InnoDB;

INSERT INTO seq_numbers (n)
WITH RECURSIVE seq (n) AS (
    SELECT 1
    UNION ALL
    SELECT n + 1 FROM seq WHERE n < 100000
)
SELECT n FROM seq;

-- ============================================================================
-- 1. MEMBER 5 REFERENCE DATA — users, roles, permissions
-- ============================================================================

INSERT INTO roles (role_name, description) VALUES
 ('ADMIN','Full system access'),
 ('DOCTOR','Clinical access'),
 ('NURSE','Limited clinical access'),
 ('PHARMACIST','Inventory and dispensing'),
 ('CASHIER','Billing and payments'),
 ('LAB_TECH','Lab orders and results'),
 ('RECEPTIONIST','Patient registration and appointments');

INSERT INTO permissions (permission_name, module, description) VALUES
 ('PATIENT_READ','Patient','View patient records'),
 ('PATIENT_WRITE','Patient','Create/update patients'),
 ('APPOINTMENT_BOOK','Appointment','Book or reschedule appointments'),
 ('CONSULT_WRITE','Clinical','Record consultations'),
 ('PRESCRIBE','Clinical','Issue prescriptions'),
 ('LAB_ORDER','Clinical','Order lab tests'),
 ('LAB_RESULT_WRITE','Clinical','Enter lab results'),
 ('BILL_CREATE','Billing','Create bills'),
 ('PAYMENT_RECORD','Billing','Record payments'),
 ('STOCK_RECEIVE','Inventory','Receive stock'),
 ('STOCK_DISPENSE','Inventory','Dispense medicines'),
 ('AUDIT_READ','Security','Read audit logs'),
 ('USER_MANAGE','Security','Create users and assign roles');

-- 60 staff users
INSERT INTO users (username, password_hash, email, full_name, phone, is_active, last_login)
SELECT CONCAT('user', LPAD(n,3,'0')),
       SHA2(CONCAT('Passw0rd!', n), 256),
       CONCAT('user', LPAD(n,3,'0'), '@hospital.lk'),
       CONCAT('Staff Member ', n),
       CONCAT('071', LPAD(1000000 + n, 7, '0')),
       IF(n % 20 = 0, FALSE, TRUE),
       NOW() - INTERVAL (n % 30) DAY
FROM seq_numbers WHERE n <= 60;

INSERT INTO user_roles (user_id, role_id, assigned_by)
SELECT n, 1 + (n % 7), 'system_seed' FROM seq_numbers WHERE n <= 60;

-- ADMIN gets everything; other roles get a sensible slice
INSERT INTO role_permissions (role_id, permission_id)
SELECT 1, permission_id FROM permissions;
INSERT INTO role_permissions (role_id, permission_id)
SELECT r.role_id, p.permission_id
FROM roles r
JOIN permissions p ON (
     (r.role_name='DOCTOR'       AND p.permission_name IN ('PATIENT_READ','CONSULT_WRITE','PRESCRIBE','LAB_ORDER'))
  OR (r.role_name='NURSE'        AND p.permission_name IN ('PATIENT_READ','PATIENT_WRITE'))
  OR (r.role_name='PHARMACIST'   AND p.permission_name IN ('STOCK_RECEIVE','STOCK_DISPENSE','PATIENT_READ'))
  OR (r.role_name='CASHIER'      AND p.permission_name IN ('BILL_CREATE','PAYMENT_RECORD','PATIENT_READ'))
  OR (r.role_name='LAB_TECH'     AND p.permission_name IN ('LAB_ORDER','LAB_RESULT_WRITE'))
  OR (r.role_name='RECEPTIONIST' AND p.permission_name IN ('PATIENT_READ','PATIENT_WRITE','APPOINTMENT_BOOK'))
);

-- ============================================================================
-- 2. MEMBER 1 — departments, doctors, patients, appointments
-- ============================================================================

INSERT INTO departments (department_name, description, location, contact_number) VALUES
 ('General Medicine','Primary care and internal medicine','Block A - Floor 1','0812200101'),
 ('Cardiology','Heart and vascular care','Block A - Floor 3','0812200102'),
 ('Orthopaedics','Bones and joints','Block B - Floor 1','0812200103'),
 ('Paediatrics','Child health','Block B - Floor 2','0812200104'),
 ('Dermatology','Skin clinic','Block C - Floor 1','0812200105'),
 ('ENT','Ear, nose and throat','Block C - Floor 2','0812200106'),
 ('Ophthalmology','Eye clinic','Block C - Floor 3','0812200107'),
 ('Neurology','Brain and nervous system','Block D - Floor 2','0812200108'),
 ('Gynaecology','Women health','Block D - Floor 3','0812200109'),
 ('Dental','Dental surgery','Block E - Floor 1','0812200110');

-- 40 doctors, 4 per department
INSERT INTO doctors (department_id, first_name, last_name, specialization, qualification,
                     license_number, phone, email, consultation_fee, is_active)
SELECT 1 + ((n - 1) % 10),
       ELT(1 + (n % 8),'Nimal','Kamal','Sunil','Ruwan','Chamara','Dilhani','Ishara','Tharindu'),
       ELT(1 + (n % 6),'Perera','Silva','Fernando','Jayasuriya','Bandara','Wickrama'),
       ELT(1 + ((n - 1) % 10),'Internal Medicine','Cardiology','Orthopaedic Surgery',
           'Paediatrics','Dermatology','ENT Surgery','Ophthalmology','Neurology',
           'Obstetrics','Dental Surgery'),
       ELT(1 + (n % 3),'MBBS, MD','MBBS, MS','MBBS, MRCP'),
       CONCAT('SLMC-', LPAD(n, 5, '0')),
       CONCAT('077', LPAD(2000000 + n, 7, '0')),
       CONCAT('doctor', LPAD(n,3,'0'), '@hospital.lk'),
       1500.00 + (n % 6) * 500,
       IF(n % 21 = 0, FALSE, TRUE)
FROM seq_numbers WHERE n <= 40;

-- 5,000 patients
INSERT INTO patients (first_name, last_name, date_of_birth, gender, blood_group, phone,
                      email, address, emergency_contact_name, emergency_contact_phone,
                      national_id, registered_date)
SELECT ELT(1 + (n % 10),'Amal','Nadeeka','Saman','Kumari','Pradeep','Hasini','Lakmal',
                        'Sewwandi','Chathura','Malsha'),
       ELT(1 + (n % 8),'Rajapaksa','Gunasekara','Herath','Dissanayake','Ekanayake',
                       'Weerasinghe','Abeywardena','Senanayake'),
       DATE_SUB(CURDATE(), INTERVAL (365 * (1 + (n % 80)) + (n % 365)) DAY),
       ELT(1 + (n % 3),'Male','Female','Other'),
       ELT(1 + (n % 8),'A+','A-','B+','B-','O+','O-','AB+','AB-'),
       CONCAT('070', LPAD(3000000 + n, 7, '0')),
       CONCAT('patient', n, '@mail.lk'),
       CONCAT(n, ', Temple Road, ', ELT(1 + (n % 5),'Kandy','Peradeniya','Katugastota','Gampola','Digana')),
       CONCAT('Guardian ', n),
       CONCAT('076', LPAD(4000000 + n, 7, '0')),
       CONCAT(LPAD(n, 9, '0'), 'V'),
       DATE_SUB(CURDATE(), INTERVAL (n % 900) DAY)
FROM seq_numbers WHERE n <= 5000;

-- ----------------------------------------------------------------------------
-- 48,000 PAST appointments.
-- Past rows are Completed / Cancelled / No-Show, so active_slot_key evaluates
-- to NULL and the UNIQUE(active_slot_key) constraint does not restrict them.
-- ----------------------------------------------------------------------------
INSERT INTO appointments (patient_id, doctor_id, appointment_date, appointment_time,
                          status, reason)
SELECT 1 + (n % 5000),
       1 + (n % 40),
       DATE_SUB(CURDATE(), INTERVAL (1 + (n % 700)) DAY),
       SEC_TO_TIME(8 * 3600 + ((n % 20) * 15 * 60)),
       ELT(1 + (n % 10),'Completed','Completed','Completed','Completed','Completed',
                        'Completed','Completed','Cancelled','Cancelled','No-Show'),
       ELT(1 + (n % 6),'Fever and cough','Follow-up','Chest pain','Routine checkup',
                       'Skin rash','Headache')
FROM seq_numbers WHERE n <= 48000;

-- ----------------------------------------------------------------------------
-- 2,000 FUTURE appointments (Scheduled/Confirmed -> active_slot_key NOT NULL).
-- The arithmetic below guarantees every (doctor, date, time) triple is unique,
-- otherwise UNIQUE(active_slot_key) would reject the load:
--   doctor  = 1 + (idx MOD 40)          40 doctors
--   d       = idx DIV 40                 0..49
--   date    = today + (d MOD 25) days    25 days
--   time    = 09:00 or 09:30 (d DIV 25)   2 slots
--   40 * 25 * 2 = 2000 distinct triples
-- ----------------------------------------------------------------------------
INSERT INTO appointments (patient_id, doctor_id, appointment_date, appointment_time,
                          status, reason)
SELECT 1 + (n % 5000),
       1 + ((n - 1) % 40),
       DATE_ADD(CURDATE(), INTERVAL (1 + (((n - 1) DIV 40) % 25)) DAY),
       SEC_TO_TIME(9 * 3600 + (((n - 1) DIV 40) DIV 25) * 1800),
       IF(n % 3 = 0, 'Confirmed', 'Scheduled'),
       'Scheduled visit'
FROM seq_numbers WHERE n <= 2000;

-- ============================================================================
-- 3. MEMBER 4 — medicines, batches, stock transactions
-- ============================================================================

INSERT INTO medicines (medicine_name, generic_name, category, manufacturer,
                       unit_of_measure, reorder_level, unit_price)
SELECT CONCAT(ELT(1 + (n % 12),'Paracetamol','Amoxicillin','Metformin','Atorvastatin',
                               'Omeprazole','Cetirizine','Losartan','Salbutamol',
                               'Ibuprofen','Azithromycin','Prednisolone','Ranitidine'),
              ' ', ELT(1 + (n % 4),'250mg','500mg','10mg','20mg')),
       ELT(1 + (n % 12),'Paracetamol','Amoxicillin','Metformin','Atorvastatin',
                        'Omeprazole','Cetirizine','Losartan','Salbutamol',
                        'Ibuprofen','Azithromycin','Prednisolone','Ranitidine'),
       ELT(1 + (n % 5),'Analgesic','Antibiotic','Antidiabetic','Cardiac','Antihistamine'),
       ELT(1 + (n % 4),'State Pharma','Astron','Hemas','Emerchemie'),
       'Tablet',
       50 + (n % 100),
       5.00 + (n % 40)
FROM seq_numbers WHERE n <= 150;

-- 900 batches. quantity_available is seeded consistently with the stock
-- transactions inserted immediately after (received - dispensed).
INSERT INTO inventory_batches (medicine_id, batch_number, quantity_received,
                               quantity_available, manufacture_date, expiry_date,
                               supplier_name, purchase_price, received_date)
SELECT 1 + (n % 150),
       CONCAT('B', LPAD(n, 6, '0')),
       1000,
       1000 - ((n % 5) * 100),
       DATE_SUB(CURDATE(), INTERVAL (200 + (n % 300)) DAY),
       DATE_ADD(CURDATE(), INTERVAL ((n % 400) - 30) DAY),   -- some already expired
       ELT(1 + (n % 3),'MedSupply Lanka','PharmaLink','CityDrug'),
       3.00 + (n % 25),
       DATE_SUB(CURDATE(), INTERVAL (n % 300) DAY)
FROM seq_numbers WHERE n <= 900;

-- One 'Receive' transaction per batch
INSERT INTO stock_transactions (batch_id, medicine_id, transaction_type, quantity,
                                transaction_date, performed_by)
SELECT b.batch_id, b.medicine_id, 'Receive', b.quantity_received,
       b.received_date, 'seed_pharmacist'
FROM inventory_batches b;

-- Dispense transactions that exactly account for the missing stock
INSERT INTO stock_transactions (batch_id, medicine_id, transaction_type, quantity,
                                transaction_date, performed_by)
SELECT b.batch_id, b.medicine_id, 'Dispense',
       b.quantity_received - b.quantity_available,
       DATE_SUB(CURDATE(), INTERVAL (b.batch_id % 120) DAY), 'seed_pharmacist'
FROM inventory_batches b
WHERE b.quantity_received > b.quantity_available;

-- ============================================================================
-- 4. MEMBER 2 — consultations, prescriptions, items, lab orders, results
-- ============================================================================

-- One consultation per COMPLETED appointment (UNIQUE(appointment_id) holds)
INSERT INTO consultations (appointment_id, patient_id, doctor_id, consultation_date,
                           chief_complaint, diagnosis, symptoms, treatment_plan, follow_up_date)
SELECT a.appointment_id, a.patient_id, a.doctor_id,
       TIMESTAMP(a.appointment_date, a.appointment_time),
       a.reason,
       ELT(1 + (a.appointment_id % 8),'Viral fever','Hypertension','Type 2 Diabetes',
           'Acute bronchitis','Gastritis','Migraine','Allergic dermatitis','Osteoarthritis'),
       ELT(1 + (a.appointment_id % 4),'Fever, body ache','Dizziness','Cough, wheezing','Pain'),
       'Medication and review',
       DATE_ADD(a.appointment_date, INTERVAL 14 DAY)
FROM appointments a
WHERE a.status = 'Completed'
ORDER BY a.appointment_id
LIMIT 20000;

INSERT INTO prescriptions (consultation_id, appointment_id, patient_id, doctor_id,
                           prescription_date, status)
SELECT c.consultation_id, c.appointment_id, c.patient_id, c.doctor_id,
       c.consultation_date,
       ELT(1 + (c.consultation_id % 5),'Completed','Completed','Completed','Active','Cancelled')
FROM consultations c
ORDER BY c.consultation_id
LIMIT 15000;

-- 2 medicines per prescription
INSERT INTO prescription_items (prescription_id, medicine_id, dosage, frequency,
                                duration_days, quantity, instructions)
SELECT p.prescription_id,
       1 + ((p.prescription_id + s.n) % 150),
       ELT(1 + (s.n % 3),'1 tablet','2 tablets','5 ml'),
       ELT(1 + (p.prescription_id % 3),'Twice daily','Three times daily','Once daily'),
       5 + (p.prescription_id % 10),
       10 + (p.prescription_id % 20),
       'After meals'
FROM prescriptions p
JOIN seq_numbers s ON s.n <= 2;

INSERT INTO lab_tests (test_name, test_category, description, normal_range, unit, price) VALUES
 ('Full Blood Count','Haematology','FBC with differential','4.0-11.0','10^9/L',1200.00),
 ('Fasting Blood Sugar','Biochemistry','FBS','70-100','mg/dL',600.00),
 ('Lipid Profile','Biochemistry','Cholesterol panel','<200','mg/dL',2500.00),
 ('Serum Creatinine','Biochemistry','Renal function','0.6-1.3','mg/dL',900.00),
 ('Liver Function Test','Biochemistry','LFT panel','7-56','U/L',3200.00),
 ('Thyroid Profile','Endocrine','TSH, T3, T4','0.4-4.0','mIU/L',3800.00),
 ('Urine Full Report','Microbiology','UFR','-','-',700.00),
 ('Chest X-Ray','Radiology','PA view','-','-',1800.00),
 ('ECG','Cardiology','12 lead','-','-',1500.00),
 ('HbA1c','Biochemistry','Glycated haemoglobin','<5.7','%',2800.00);

INSERT INTO lab_orders (appointment_id, patient_id, doctor_id, test_id, order_date,
                        priority, status)
SELECT c.appointment_id, c.patient_id, c.doctor_id,
       1 + (c.consultation_id % 10),
       c.consultation_date,
       ELT(1 + (c.consultation_id % 6),'Routine','Routine','Routine','Routine','Urgent','Stat'),
       ELT(1 + (c.consultation_id % 8),'Completed','Completed','Completed','Completed',
                                       'Completed','In-Progress','Pending','Cancelled')
FROM consultations c
ORDER BY c.consultation_id
LIMIT 12000;

-- One result per COMPLETED order (UNIQUE(order_id) holds)
INSERT INTO lab_results (order_id, result_value, result_date, performed_by, remarks, is_abnormal)
SELECT lo.order_id,
       CONCAT(ROUND(5 + (lo.order_id % 90) / 10, 1)),
       DATE_ADD(lo.order_date, INTERVAL 1 DAY),
       CONCAT('Tech-', 1 + (lo.order_id % 6)),
       'Reviewed',
       (lo.order_id % 7 = 0)
FROM lab_orders lo
WHERE lo.status = 'Completed';

INSERT INTO pharmacy_dispensations (prescription_id, patient_id, dispensed_date,
                                    dispensed_by, total_items, status)
SELECT p.prescription_id, p.patient_id,
       DATE_ADD(p.prescription_date, INTERVAL 1 HOUR),
       CONCAT('Pharm-', 1 + (p.prescription_id % 4)),
       2,
       IF(p.prescription_id % 9 = 0, 'Partial', 'Completed')
FROM prescriptions p
WHERE p.status = 'Completed';

-- ============================================================================
-- 5. MEMBER 3 — services, insurance, bills, items, payments
-- ============================================================================

INSERT INTO services (service_name, service_category, description, price) VALUES
 ('Doctor Consultation','Consultation','OPD consultation',2000.00),
 ('Specialist Consultation','Consultation','Specialist OPD',3500.00),
 ('Dressing','Procedure','Wound dressing',800.00),
 ('Nebulisation','Procedure','Nebuliser therapy',1200.00),
 ('Minor Surgery','Procedure','Minor theatre procedure',15000.00),
 ('Room Charge - General','Ward','Per day general ward',4500.00),
 ('Room Charge - Private','Ward','Per day private room',9000.00),
 ('Lab Service Charge','Lab','Sample handling',500.00),
 ('Pharmacy Service Charge','Pharmacy','Dispensing fee',300.00),
 ('Ambulance','Transport','Per trip within city',6000.00);

INSERT INTO insurance_profiles (patient_id, provider_name, policy_number,
                                coverage_percentage, valid_from, valid_to)
SELECT n,
       ELT(1 + (n % 4),'Ceylinco','AIA','Union Assurance','SLIC'),
       CONCAT('POL-', LPAD(n, 8, '0')),
       ELT(1 + (n % 4), 50.00, 70.00, 80.00, 100.00),
       DATE_SUB(CURDATE(), INTERVAL 200 DAY),
       DATE_ADD(CURDATE(), INTERVAL 400 DAY)
FROM seq_numbers WHERE n <= 1500;

-- 20,000 bills, one per completed appointment
INSERT INTO bills (patient_id, appointment_id, bill_date, subtotal, discount, tax,
                   total_amount, paid_amount, balance_amount, status)
SELECT a.patient_id, a.appointment_id,
       TIMESTAMP(a.appointment_date, a.appointment_time),
       0, 0, 0, 0, 0, 0, 'Pending'
FROM appointments a
WHERE a.status = 'Completed'
ORDER BY a.appointment_id
LIMIT 20000;

-- 2 line items per bill
INSERT INTO bill_items (bill_id, service_id, description, quantity, unit_price, amount)
SELECT b.bill_id,
       1 + ((b.bill_id + s.n) % 10),
       'Auto-generated seed item',
       1 + (b.bill_id % 2),
       sv.price,
       (1 + (b.bill_id % 2)) * sv.price
FROM bills b
JOIN seq_numbers s ON s.n <= 2
JOIN services sv ON sv.service_id = 1 + ((b.bill_id + s.n) % 10);

-- Roll the line items up into the bill header (subtotal / tax / total)
UPDATE bills b
JOIN (SELECT bill_id, SUM(amount) AS amt FROM bill_items GROUP BY bill_id) t
  ON t.bill_id = b.bill_id
SET b.subtotal     = t.amt,
    b.tax          = ROUND(t.amt * 0.02, 2),
    b.total_amount = ROUND(t.amt * 1.02, 2),
    b.balance_amount = ROUND(t.amt * 1.02, 2);

-- Payments: 60% of bills paid in full, 20% partly, 20% unpaid
INSERT INTO payments (bill_id, payment_date, amount, payment_method, reference_number, received_by)
SELECT b.bill_id,
       DATE_ADD(b.bill_date, INTERVAL 2 HOUR),
       IF(b.bill_id % 5 < 3, b.total_amount, ROUND(b.total_amount * 0.4, 2)),
       ELT(1 + (b.bill_id % 4),'Cash','Card','Insurance','Bank Transfer'),
       CONCAT('RCPT-', LPAD(b.bill_id, 8, '0')),
       CONCAT('Cashier-', 1 + (b.bill_id % 3))
FROM bills b
WHERE b.bill_id % 5 < 4;

-- Re-derive the header from the payments so paid/balance/status are CONSISTENT.
-- (This is exactly the invariant the trigger in file 05 maintains at runtime.)
UPDATE bills b
LEFT JOIN (SELECT bill_id, SUM(amount) AS paid FROM payments GROUP BY bill_id) p
  ON p.bill_id = b.bill_id
SET b.paid_amount    = COALESCE(p.paid, 0),
    b.balance_amount = b.total_amount - COALESCE(p.paid, 0),
    b.status = CASE WHEN COALESCE(p.paid,0) = 0 THEN 'Pending'
                    WHEN COALESCE(p.paid,0) >= b.total_amount THEN 'Paid'
                    ELSE 'Partial' END;

-- ============================================================================
-- 6. AUDIT HISTORY — 50,000 rows spread over a year (for L4 range-scan demo)
-- ============================================================================
INSERT INTO audit_logs (user_id, entity_name, entity_id, action, new_value, ip_address, created_at)
SELECT 1 + (n % 60),
       ELT(1 + (n % 6),'patients','appointments','payments','prescriptions',
                       'stock_transactions','users'),
       n,
       ELT(1 + (n % 5),'INSERT','UPDATE','UPDATE','DELETE','LOGIN'),
       CONCAT('seed event #', n),
       CONCAT('192.168.', 1 + (n % 5), '.', 1 + (n % 200)),
       NOW() - INTERVAL (n % 525600) MINUTE
FROM seq_numbers WHERE n <= 50000;

-- ============================================================================
-- 7. OPTIMIZER STATISTICS  — run this or EXPLAIN row estimates will be wrong
-- ============================================================================
ANALYZE TABLE patients, doctors, appointments, consultations, prescriptions,
              prescription_items, lab_orders, lab_results, bills, bill_items,
              payments, medicines, inventory_batches, stock_transactions,
              audit_logs, users;

-- ============================================================================
-- 8. VERIFY THE LOAD  (show this table in the viva)
-- ============================================================================
SELECT 'patients' AS table_name, COUNT(*) AS rows_loaded FROM patients
UNION ALL SELECT 'appointments',       COUNT(*) FROM appointments
UNION ALL SELECT 'consultations',      COUNT(*) FROM consultations
UNION ALL SELECT 'prescriptions',      COUNT(*) FROM prescriptions
UNION ALL SELECT 'prescription_items', COUNT(*) FROM prescription_items
UNION ALL SELECT 'lab_orders',         COUNT(*) FROM lab_orders
UNION ALL SELECT 'lab_results',        COUNT(*) FROM lab_results
UNION ALL SELECT 'bills',              COUNT(*) FROM bills
UNION ALL SELECT 'bill_items',         COUNT(*) FROM bill_items
UNION ALL SELECT 'payments',           COUNT(*) FROM payments
UNION ALL SELECT 'inventory_batches',  COUNT(*) FROM inventory_batches
UNION ALL SELECT 'stock_transactions', COUNT(*) FROM stock_transactions
UNION ALL SELECT 'audit_logs',         COUNT(*) FROM audit_logs;

-- Consistency check: every bill header must agree with its payments
SELECT COUNT(*) AS inconsistent_bills
FROM bills b
LEFT JOIN (SELECT bill_id, SUM(amount) paid FROM payments GROUP BY bill_id) p
       ON p.bill_id = b.bill_id
WHERE b.paid_amount <> COALESCE(p.paid, 0)
   OR b.balance_amount <> b.total_amount - COALESCE(p.paid, 0);
-- Expected: 0

-- END OF FILE 02


-- ############################################################################
-- ##  STAGE 3  --  03_functions_views.sql
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
-- ##  Run this in front of the examiner. Every number must match the
-- ##  requirement sheet, and every consistency check must return 0.
-- ############################################################################

USE hospital_management;

-- ---------------------------------------------------------------------------
-- 6.1  OBJECT COUNT vs THE REQUIREMENT SHEET
-- ---------------------------------------------------------------------------
SELECT 'Base tables'      AS object_type,
       COUNT(*)           AS actual,
       25                 AS required,
       IF(COUNT(*) = 25, 'PASS', 'CHECK') AS result
FROM information_schema.TABLES
WHERE TABLE_SCHEMA = 'hospital_management'
  AND TABLE_TYPE   = 'BASE TABLE'
  AND TABLE_NAME NOT IN ('seq_numbers','monthly_revenue_summary','txn_schedule_log')
UNION ALL
SELECT 'Views', COUNT(*), 15, IF(COUNT(*) = 15, 'PASS', 'CHECK')
FROM information_schema.VIEWS WHERE TABLE_SCHEMA = 'hospital_management'
UNION ALL
SELECT 'Functions', COUNT(*), 15, IF(COUNT(*) = 15, 'PASS', 'CHECK')
FROM information_schema.ROUTINES
WHERE ROUTINE_SCHEMA = 'hospital_management' AND ROUTINE_TYPE = 'FUNCTION'
UNION ALL
SELECT 'Procedures (15 + 1 utility)', COUNT(*), 16, IF(COUNT(*) = 16, 'PASS', 'CHECK')
FROM information_schema.ROUTINES
WHERE ROUTINE_SCHEMA = 'hospital_management' AND ROUTINE_TYPE = 'PROCEDURE'
UNION ALL
SELECT 'Triggers', COUNT(*), 15, IF(COUNT(*) = 15, 'PASS', 'CHECK')
FROM information_schema.TRIGGERS WHERE TRIGGER_SCHEMA = 'hospital_management'
UNION ALL
SELECT 'Secondary indexes (idx_*)', COUNT(DISTINCT INDEX_NAME), 15,
       IF(COUNT(DISTINCT INDEX_NAME) = 15, 'PASS', 'CHECK')
FROM information_schema.STATISTICS
WHERE TABLE_SCHEMA = 'hospital_management' AND INDEX_NAME LIKE 'idx_%';

-- ---------------------------------------------------------------------------
-- 6.2  PER-MEMBER OWNERSHIP MAP
--      Each member points at their own block and says "these are mine".
-- ---------------------------------------------------------------------------
SELECT 'Member 1 - Patient & Appointment' AS module, 'FUNCTION' AS kind, ROUTINE_NAME AS object_name
FROM information_schema.ROUTINES
WHERE ROUTINE_SCHEMA='hospital_management' AND ROUTINE_TYPE='FUNCTION'
  AND ROUTINE_NAME IN ('fn_calculate_patient_age','fn_count_patient_appointments','fn_check_doctor_availability')
UNION ALL
SELECT 'Member 1 - Patient & Appointment','PROCEDURE',ROUTINE_NAME
FROM information_schema.ROUTINES
WHERE ROUTINE_SCHEMA='hospital_management' AND ROUTINE_TYPE='PROCEDURE'
  AND ROUTINE_NAME IN ('sp_register_or_update_patient','sp_book_or_reschedule_appointment','sp_search_doctor_availability')
UNION ALL
SELECT 'Member 1 - Patient & Appointment','TRIGGER',TRIGGER_NAME
FROM information_schema.TRIGGERS
WHERE TRIGGER_SCHEMA='hospital_management' AND EVENT_OBJECT_TABLE IN ('appointments','patients')
UNION ALL
SELECT 'Member 2 - Clinical Records','TRIGGER',TRIGGER_NAME
FROM information_schema.TRIGGERS
WHERE TRIGGER_SCHEMA='hospital_management' AND EVENT_OBJECT_TABLE IN ('consultations','prescription_items','lab_results')
UNION ALL
SELECT 'Member 3 - Billing & Payments','TRIGGER',TRIGGER_NAME
FROM information_schema.TRIGGERS
WHERE TRIGGER_SCHEMA='hospital_management' AND EVENT_OBJECT_TABLE IN ('payments')
UNION ALL
SELECT 'Member 4 - Inventory & Pharmacy','TRIGGER',TRIGGER_NAME
FROM information_schema.TRIGGERS
WHERE TRIGGER_SCHEMA='hospital_management' AND EVENT_OBJECT_TABLE IN ('stock_transactions','inventory_batches')
UNION ALL
SELECT 'Member 5 - Security & Auditing','TRIGGER',TRIGGER_NAME
FROM information_schema.TRIGGERS
WHERE TRIGGER_SCHEMA='hospital_management' AND EVENT_OBJECT_TABLE IN ('users','role_permissions')
ORDER BY module, kind, object_name;

-- ---------------------------------------------------------------------------
-- 6.3  DATA VOLUME  (proves the EXPLAIN demos in file 07 are meaningful)
-- ---------------------------------------------------------------------------
SELECT 'patients' AS table_name, COUNT(*) AS rows_loaded FROM patients
UNION ALL SELECT 'doctors',            COUNT(*) FROM doctors
UNION ALL SELECT 'appointments',       COUNT(*) FROM appointments
UNION ALL SELECT 'consultations',      COUNT(*) FROM consultations
UNION ALL SELECT 'prescriptions',      COUNT(*) FROM prescriptions
UNION ALL SELECT 'prescription_items', COUNT(*) FROM prescription_items
UNION ALL SELECT 'lab_orders',         COUNT(*) FROM lab_orders
UNION ALL SELECT 'bills',              COUNT(*) FROM bills
UNION ALL SELECT 'payments',           COUNT(*) FROM payments
UNION ALL SELECT 'inventory_batches',  COUNT(*) FROM inventory_batches
UNION ALL SELECT 'stock_transactions', COUNT(*) FROM stock_transactions
UNION ALL SELECT 'audit_logs',         COUNT(*) FROM audit_logs;

-- ---------------------------------------------------------------------------
-- 6.4  CONSISTENCY PROOFS  -- every one of these MUST return 0 rows.
--      This is the "C" in ACID, checked against the whole seeded database.
-- ---------------------------------------------------------------------------

-- (a) Billing: paid_amount and balance_amount must agree with the payments table
SELECT b.bill_id, b.total_amount, b.paid_amount, b.balance_amount,
       COALESCE(SUM(p.amount),0) AS actual_paid
FROM bills b LEFT JOIN payments p ON p.bill_id = b.bill_id
GROUP BY b.bill_id, b.total_amount, b.paid_amount, b.balance_amount
HAVING b.paid_amount    <> actual_paid
    OR b.balance_amount <> b.total_amount - actual_paid;

-- (b) Inventory: no batch may hold negative stock
SELECT batch_id, medicine_id, quantity_available
FROM inventory_batches WHERE quantity_available < 0;

-- (c) Inventory: available stock must equal received minus dispensed
SELECT ib.batch_id, ib.quantity_available,
       ib.quantity_received
       - COALESCE(SUM(CASE WHEN st.transaction_type = 'Dispense' THEN st.quantity END),0)
       + COALESCE(SUM(CASE WHEN st.transaction_type = 'Adjustment' THEN st.quantity END),0)
         AS expected_available
FROM inventory_batches ib
LEFT JOIN stock_transactions st ON st.batch_id = ib.batch_id
GROUP BY ib.batch_id, ib.quantity_available, ib.quantity_received
HAVING ib.quantity_available <> expected_available;

-- (d) Appointments: no doctor may hold two LIVE appointments in one slot
SELECT doctor_id, appointment_date, appointment_time, COUNT(*) AS live_bookings
FROM appointments
WHERE status IN ('Scheduled','Confirmed')
GROUP BY doctor_id, appointment_date, appointment_time
HAVING COUNT(*) > 1;

-- (e) Referential integrity spot-check: orphaned children
SELECT 'orphan appointments' AS problem, COUNT(*) AS n
FROM appointments a LEFT JOIN patients p ON p.patient_id = a.patient_id
WHERE p.patient_id IS NULL
UNION ALL
SELECT 'orphan prescription_items', COUNT(*)
FROM prescription_items pi LEFT JOIN prescriptions pr ON pr.prescription_id = pi.prescription_id
WHERE pr.prescription_id IS NULL
HAVING n > 0;

-- ---------------------------------------------------------------------------
-- 6.5  SMOKE TEST  -- one call from every member's module, end to end.
--      If this block runs clean, the whole build is live.
-- ---------------------------------------------------------------------------
SET @app_user_id = 1;

SELECT fn_calculate_patient_age(1)                    AS m1_patient_age,
       fn_count_prescription_medicines(1)             AS m2_medicines_on_rx_1,
       fn_calculate_bill_balance(1)                   AS m3_balance_bill_1,
       fn_calculate_available_stock(1)                AS m4_stock_medicine_1,
       fn_check_user_permission(1,'PATIENT_READ')     AS m5_user1_can_read;

SELECT * FROM vw_upcoming_appointments        LIMIT 5;   -- Member 1
SELECT * FROM vw_patient_clinical_history     LIMIT 5;   -- Member 2
SELECT * FROM vw_outstanding_bills            LIMIT 5;   -- Member 3
SELECT * FROM vw_current_medicine_stock       LIMIT 5;   -- Member 4
SELECT * FROM vw_recent_audit_activity        LIMIT 5;   -- Member 5

-- ---------------------------------------------------------------------------
-- BUILD COMPLETE.
-- Next: 06_transactions_L9_L10.sql  (run block by block, NOT as a whole file)
-- ---------------------------------------------------------------------------

-- END OF MASTER BUILD


-- ############################################################################
-- ############################################################################
-- ##
-- ##   PART B  --  LESSON DEMONSTRATIONS  (L1 to L13)
-- ##
-- ##   PART A above (Stages 1-6) is run ONCE, as a whole file.
-- ##   PART B below is run BLOCK BY BLOCK in front of the examiner.
-- ##   Do NOT press Execute-All from here down - each block is a separate
-- ##   demonstration and several of them are SUPPOSED to fail, so that you
-- ##   can show the error and then show the fix.
-- ##
-- ##   In MySQL Workbench: put the cursor inside a block and press
-- ##   Ctrl+Enter (Execute Current Statement) instead of Ctrl+Shift+Enter.
-- ##
-- ##   STAGE 7  L9-L10  Transactions           (10 transactions, 2 per member)
-- ##   STAGE 8  L1-L8   File org, indexing, query optimization
-- ##   STAGE 9  L11-L13 View serializability + concurrency control
-- ##
-- ##   ONE WARNING, AND IT IS IMPORTANT:
-- ##   Stage 9 needs TWO OR THREE SEPARATE CONNECTIONS (Workbench tabs).
-- ##   A single script cannot demonstrate two transactions running at the
-- ##   same time - that is the whole point of concurrency. The blocks are
-- ##   labelled SESSION A / SESSION B / SESSION C with step numbers, so open
-- ##   the tabs, then run step 1 in A, step 2 in B, step 3 in A, and so on.
-- ##
-- ############################################################################
-- ############################################################################



-- ############################################################################
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

    -- Step 2: insert the payment fact (half the bill)
    INSERT INTO payments (bill_id, amount, payment_method, reference_number, received_by)
    SELECT @bill, ROUND(total_amount / 2, 2), 'Card', 'VIVA-PAY-1', 'Cashier-1'
      FROM bills WHERE bill_id = @bill;

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
-- ############################################################################

-- ============================================================================
--  FILE 07 of 08 : FILE ORGANIZATION (L1-L3), INDEXING (L4),
--                  QUERY OPTIMIZATION (L5-L6), ADVANCED OPTIMIZATION (L7-L8)
-- ============================================================================
--  HOW TO PRESENT THIS FILE
--  Every demo has the same shape:  BEFORE  ->  EXPLAIN  ->  CHANGE  ->  EXPLAIN.
--  Read three columns out of EXPLAIN and you can defend any of them:
--     type  : ALL = full table scan (bad)   ref/range/eq_ref/const = index used
--     rows  : the optimizer's estimate of rows examined
--     Extra : "Using filesort" / "Using temporary" = extra work,
--             "Using index" = COVERING index, the table itself is never touched
-- ============================================================================

USE hospital_management;

-- ############################################################################
-- ############################################################################
--  L1 - L3 : FILE ORGANIZATION
-- ############################################################################
-- ############################################################################
--
--  Four organizations, one table's worth of data in each, so the differences
--  are measurable rather than theoretical.
--
--    HEAP (unordered)  - rows sit wherever there is free space; insert is O(1),
--                        every search is a full scan.
--    SEQUENTIAL/ORDERED- rows physically sorted by the key; range scans are
--                        cheap, inserts must find their place.
--    HASH              - a hash function maps key -> bucket; equality lookup is
--                        ~O(1) but a RANGE query is impossible (no ordering).
--    CLUSTERED B+TREE  - what InnoDB always does with the PRIMARY KEY: the
--                        table IS the index, leaves hold the full rows.
-- ----------------------------------------------------------------------------

DROP TABLE IF EXISTS fo_heap, fo_ordered, fo_hash;

-- (a) HEAP FILE — InnoDB with NO primary key. MySQL adds a hidden 6-byte
--     row-id, so rows stay in insertion order and nothing is searchable.
CREATE TABLE fo_heap (
    appointment_id   INT NOT NULL,
    doctor_id        INT NOT NULL,
    patient_id       INT NOT NULL,
    appointment_date DATE NOT NULL,
    appointment_time TIME NOT NULL
) ENGINE=InnoDB;

-- (b) ORDERED / SEQUENTIAL FILE — clustered on (appointment_date, id).
--     Physically sorted by date, which is exactly what a date-range report wants.
CREATE TABLE fo_ordered (
    appointment_id   INT NOT NULL,
    doctor_id        INT NOT NULL,
    patient_id       INT NOT NULL,
    appointment_date DATE NOT NULL,
    appointment_time TIME NOT NULL,
    PRIMARY KEY (appointment_date, appointment_id)
) ENGINE=InnoDB;

-- (c) HASH FILE — MEMORY engine, HASH index on the search key.
CREATE TABLE fo_hash (
    appointment_id   INT NOT NULL,
    doctor_id        INT NOT NULL,
    patient_id       INT NOT NULL,
    appointment_date DATE NOT NULL,
    appointment_time TIME NOT NULL,
    INDEX idx_hash_doctor USING HASH (doctor_id)
) ENGINE=MEMORY;

INSERT INTO fo_heap
SELECT appointment_id, doctor_id, patient_id, appointment_date, appointment_time
FROM appointments LIMIT 20000;

INSERT INTO fo_ordered
SELECT appointment_id, doctor_id, patient_id, appointment_date, appointment_time
FROM appointments LIMIT 20000;

INSERT INTO fo_hash
SELECT appointment_id, doctor_id, patient_id, appointment_date, appointment_time
FROM appointments LIMIT 20000;

ANALYZE TABLE fo_heap, fo_ordered;

-- --- Physical picture: how much space each organization costs -----------------
SELECT TABLE_NAME, ENGINE, TABLE_ROWS,
       DATA_LENGTH  AS data_bytes,
       INDEX_LENGTH AS index_bytes
FROM information_schema.TABLES
WHERE TABLE_SCHEMA = 'hospital_management'
  AND TABLE_NAME IN ('fo_heap','fo_ordered','fo_hash','appointments');
-- TALKING POINT: fo_ordered costs more index_bytes than fo_heap. Ordering is
-- not free - you pay storage and insert cost to buy fast range access.

-- --- (1) RANGE QUERY : ordered file wins ------------------------------------
EXPLAIN SELECT COUNT(*) FROM fo_heap
 WHERE appointment_date BETWEEN CURDATE() - INTERVAL 90 DAY AND CURDATE();
-- type = ALL  -> 20,000 rows scanned

EXPLAIN SELECT COUNT(*) FROM fo_ordered
 WHERE appointment_date BETWEEN CURDATE() - INTERVAL 90 DAY AND CURDATE();
-- type = range -> only the matching leaf pages of the clustered B+Tree

-- --- (2) EQUALITY QUERY : hash organization wins ------------------------------
EXPLAIN SELECT COUNT(*) FROM fo_hash  WHERE doctor_id = 7;   -- type = ref (hash)
EXPLAIN SELECT COUNT(*) FROM fo_heap  WHERE doctor_id = 7;   -- type = ALL

-- --- (3) THE LIMIT OF HASHING : a hash index cannot do ranges ----------------
EXPLAIN SELECT COUNT(*) FROM fo_hash WHERE doctor_id BETWEEN 5 AND 10;
-- type = ALL even though doctor_id is indexed. A hash of 5 tells you nothing
-- about where 6 lives. THIS is why InnoDB uses B+Trees and not hash tables as
-- its primary organization.

-- --- (4) CLUSTERED vs SECONDARY INDEX in the real table ---------------------
SHOW INDEX FROM appointments;
-- PRIMARY is the clustered index: its leaves ARE the rows.
-- Every secondary index leaf stores the PRIMARY KEY value, so a secondary
-- lookup that needs extra columns costs a second hop into the clustered index
-- ("bookmark lookup"). A COVERING index avoids that hop - see L7 below.

EXPLAIN SELECT appointment_id, patient_id, status         -- needs extra columns
  FROM appointments WHERE doctor_id = 7 AND appointment_date = CURDATE();

EXPLAIN SELECT doctor_id, appointment_date, appointment_time  -- all in the index
  FROM appointments WHERE doctor_id = 7 AND appointment_date = CURDATE();
-- Extra: "Using index"  <- covering, zero table access

-- ----------------------------------------------------------------------------
--  PER-MEMBER FILE ORGANIZATION DECISION (state this in your own section)
--    M1 appointments        : clustered on appointment_id, but the workload is
--                             "one doctor, one day" -> composite B+Tree index
--                             on (doctor_id, appointment_date, appointment_time).
--    M2 lab_orders          : status is low-cardinality (4 values) so it must
--                             be the LEADING column only when combined with
--                             priority; otherwise the optimizer ignores it.
--    M3 payments            : insert-heavy, append-only, read by bill -> the
--                             clustered PK gives sequential inserts (no page
--                             splits); (bill_id, payment_date) serves the reads.
--    M4 inventory_batches   : FIFO/FEFO access is a RANGE on expiry_date ->
--                             ordered B+Tree, never a hash.
--    M5 audit_logs          : pure time-series, append-only. Clustered PK is
--                             monotonic; the reporting access path is a RANGE
--                             on created_at.
-- ----------------------------------------------------------------------------

-- ############################################################################
-- ############################################################################
--  L4 : INDEXING + EXPLAIN   (3 indexes per member, before -> after)
-- ############################################################################
-- ############################################################################

-- ============================================================================
-- MEMBER 1 — appointments / doctors
-- ============================================================================

-- INDEX 1: idx_appointments_doctor_datetime
ALTER TABLE appointments DROP INDEX idx_appointments_doctor_datetime;
EXPLAIN SELECT appointment_id, patient_id, appointment_time, status
  FROM appointments
 WHERE doctor_id = 7
   AND appointment_date BETWEEN CURDATE() AND CURDATE() + INTERVAL 7 DAY;
-- BEFORE: type=ALL, rows ~ 50000

CREATE INDEX idx_appointments_doctor_datetime
    ON appointments (doctor_id, appointment_date, appointment_time);
EXPLAIN SELECT appointment_id, patient_id, appointment_time, status
  FROM appointments
 WHERE doctor_id = 7
   AND appointment_date BETWEEN CURDATE() AND CURDATE() + INTERVAL 7 DAY;
-- AFTER: type=range, key=idx_appointments_doctor_datetime, rows in the tens

-- Measure it, don't just claim it:
FLUSH STATUS;
SELECT COUNT(*) FROM appointments
 WHERE doctor_id = 7 AND appointment_date BETWEEN CURDATE() AND CURDATE() + INTERVAL 7 DAY;
SHOW STATUS LIKE 'Handler_read%';
-- Handler_read_next high + Handler_read_rnd_next ~0  => index scan, not table scan

-- INDEX 2: idx_appointments_patient_status
EXPLAIN SELECT appointment_id, appointment_date FROM appointments
 WHERE patient_id = 101 AND status = 'Completed';

-- INDEX 3: idx_doctors_department_active
EXPLAIN SELECT doctor_id, first_name, last_name FROM doctors
 WHERE department_id = 2 AND is_active = TRUE;

-- WHY THE COLUMN ORDER IS (doctor_id, date, time) AND NOT (date, doctor_id):
-- a composite B+Tree can only use a LEFTMOST PREFIX. Our queries always know
-- the doctor and sometimes the date, never the date alone. Prove it:
EXPLAIN SELECT * FROM appointments WHERE appointment_time = '09:00:00';
-- key = NULL: the 3rd column of the index is useless on its own.

-- ============================================================================
-- MEMBER 2 — clinical records
-- ============================================================================
EXPLAIN SELECT order_id, status FROM lab_orders
 WHERE appointment_id = 500 AND status = 'Completed';          -- idx_lab_orders_appointment_status

EXPLAIN SELECT order_id, priority, order_date FROM lab_orders
 WHERE status = 'Pending' AND priority = 'Stat';               -- idx_lab_orders_status_priority

EXPLAIN SELECT prescription_id, prescription_date FROM prescriptions
 WHERE appointment_id = 500
 ORDER BY prescription_date DESC;                              -- idx_prescriptions_appointment_date
-- Extra should NOT say "Using filesort": the index already supplies the order.

-- ============================================================================
-- MEMBER 3 — billing
-- ============================================================================
EXPLAIN SELECT payment_id, amount FROM payments
 WHERE bill_id = 1000 ORDER BY payment_date;                   -- idx_payments_bill_date

EXPLAIN SELECT bill_id, balance_amount FROM bills
 WHERE patient_id = 101 AND status IN ('Pending','Partial');   -- idx_bills_patient_status

EXPLAIN SELECT bill_item_id, amount FROM bill_items
 WHERE bill_id = 1000 AND service_id = 3;                      -- idx_bill_items_bill_service

-- ============================================================================
-- MEMBER 4 — inventory
-- ============================================================================
EXPLAIN SELECT batch_id, expiry_date FROM inventory_batches
 WHERE expiry_date <= CURDATE() + INTERVAL 30 DAY;             -- idx_inventory_batches_expiry

EXPLAIN SELECT batch_id, quantity_available FROM inventory_batches
 WHERE medicine_id = 1 AND expiry_date >= CURDATE()
 ORDER BY expiry_date;                                         -- idx_..._medicine_expiry (FIFO path)

EXPLAIN SELECT transaction_id, quantity FROM stock_transactions
 WHERE batch_id = 10 AND transaction_date >= CURDATE() - INTERVAL 30 DAY;

-- ============================================================================
-- MEMBER 5 — audit
-- ============================================================================
ALTER TABLE audit_logs DROP INDEX idx_audit_logs_created_at;
EXPLAIN SELECT COUNT(*) FROM audit_logs
 WHERE created_at >= NOW() - INTERVAL 7 DAY;
-- BEFORE: type=ALL over 50,000 rows

CREATE INDEX idx_audit_logs_created_at ON audit_logs (created_at);
EXPLAIN SELECT COUNT(*) FROM audit_logs
 WHERE created_at >= NOW() - INTERVAL 7 DAY;
-- AFTER: type=range, Extra "Using index" (covering - COUNT needs nothing else)

EXPLAIN SELECT log_id, entity_id FROM audit_logs
 WHERE entity_name = 'payments' AND action = 'INSERT';         -- idx_audit_logs_entity_action

EXPLAIN SELECT user_id, username FROM users
 WHERE is_active = TRUE AND username = 'user001';              -- idx_users_active_username

-- ############################################################################
-- ############################################################################
--  L5 - L6 : QUERY OPTIMIZATION   *** MEMBER 2 IS THE MAIN DEMONSTRATOR ***
-- ############################################################################
-- ############################################################################
--
--  Five anti-patterns, each with the rewrite. Run EXPLAIN on both versions.
-- ----------------------------------------------------------------------------

-- ---------------------------------------------------------------------------
-- (1) A FUNCTION ON AN INDEXED COLUMN KILLS THE INDEX  ("non-SARGable")
-- ---------------------------------------------------------------------------
-- SLOW: YEAR() must be evaluated for every row, so the index cannot be used.
EXPLAIN SELECT COUNT(*) FROM appointments
 WHERE YEAR(appointment_date) = YEAR(CURDATE());

-- FAST: rewrite as a RANGE on the raw column. Same answer, index usable.
EXPLAIN SELECT COUNT(*) FROM appointments
 WHERE appointment_date >= MAKEDATE(YEAR(CURDATE()), 1)
   AND appointment_date <  MAKEDATE(YEAR(CURDATE()) + 1, 1);
-- RULE: keep the indexed column BARE on the left-hand side of the comparison.

-- ---------------------------------------------------------------------------
-- (2) LEADING-WILDCARD LIKE
-- ---------------------------------------------------------------------------
CREATE INDEX idx_patients_phone ON patients (phone);   -- the demo needs one
EXPLAIN SELECT patient_id FROM patients WHERE phone LIKE '%1234';   -- type = ALL
EXPLAIN SELECT patient_id FROM patients WHERE phone LIKE '0703%';   -- type = range
-- A B+Tree is ordered by PREFIX. '%x' has no prefix to seek on.

-- ---------------------------------------------------------------------------
-- (3) CORRELATED SUBQUERY -> JOIN  (Member 2's headline example)
-- ---------------------------------------------------------------------------
-- SLOW: the inner query runs once PER consultation row.
EXPLAIN ANALYZE
SELECT c.consultation_id, c.diagnosis,
       (SELECT COUNT(*) FROM prescriptions p
         WHERE p.consultation_id = c.consultation_id) AS rx_count
FROM consultations c
WHERE c.consultation_date >= CURDATE() - INTERVAL 180 DAY;

-- FAST: aggregate ONCE, then join.
EXPLAIN ANALYZE
SELECT c.consultation_id, c.diagnosis, COALESCE(p.rx_count, 0) AS rx_count
FROM consultations c
LEFT JOIN (SELECT consultation_id, COUNT(*) AS rx_count
             FROM prescriptions
            GROUP BY consultation_id) p
       ON p.consultation_id = c.consultation_id
WHERE c.consultation_date >= CURDATE() - INTERVAL 180 DAY;

-- ---------------------------------------------------------------------------
-- (4) "OR" ACROSS TWO DIFFERENT INDEXES -> UNION ALL
-- ---------------------------------------------------------------------------
EXPLAIN SELECT order_id FROM lab_orders
 WHERE appointment_id = 500 OR priority = 'Stat';               -- often type=ALL

EXPLAIN SELECT order_id FROM lab_orders WHERE appointment_id = 500
 UNION ALL
 SELECT order_id FROM lab_orders WHERE priority = 'Stat' AND appointment_id <> 500;
-- Each branch can use its own index.

-- ---------------------------------------------------------------------------
-- (5) SELECT *  vs  ONLY WHAT YOU NEED
-- ---------------------------------------------------------------------------
EXPLAIN SELECT * FROM lab_orders WHERE status = 'Pending' AND priority = 'Stat';
EXPLAIN SELECT order_id, patient_id FROM lab_orders
 WHERE status = 'Pending' AND priority = 'Stat';
-- SELECT * drags TEXT columns off-page and blocks covering indexes.

-- Member 2's real query, optimised end to end:
EXPLAIN ANALYZE
SELECT lo.order_id, lt.test_name, lo.priority, lo.order_date
FROM lab_orders lo
JOIN lab_tests  lt ON lt.test_id = lo.test_id
WHERE lo.status = 'Pending'
  AND lo.order_date >= CURDATE() - INTERVAL 30 DAY
ORDER BY lo.priority, lo.order_date
LIMIT 50;

-- ############################################################################
-- ############################################################################
--  L7 - L8 : ADVANCED QUERY OPTIMIZATION  *** MEMBER 5 IS THE MAIN DEMO ***
-- ############################################################################
-- ############################################################################

-- ---------------------------------------------------------------------------
-- (A) MEMBER 1 — complex appointment report
--     Window function instead of a self-join: one pass over the data.
-- ---------------------------------------------------------------------------
EXPLAIN ANALYZE
WITH doctor_load AS (
    SELECT d.doctor_id,
           CONCAT(d.first_name,' ',d.last_name) AS doctor_name,
           dep.department_name,
           COUNT(a.appointment_id) AS appts,
           SUM(a.status = 'No-Show') AS no_shows
    FROM doctors d
    JOIN departments dep ON dep.department_id = d.department_id
    LEFT JOIN appointments a
           ON a.doctor_id = d.doctor_id
          AND a.appointment_date >= CURDATE() - INTERVAL 90 DAY
    GROUP BY d.doctor_id, doctor_name, dep.department_name
)
SELECT doctor_name, department_name, appts, no_shows,
       ROUND(100 * no_shows / NULLIF(appts,0), 1) AS no_show_pct,
       RANK() OVER (PARTITION BY department_name ORDER BY appts DESC) AS rank_in_dept
FROM doctor_load
ORDER BY department_name, rank_in_dept;

-- ---------------------------------------------------------------------------
-- (B) MEMBER 2 — patient clinical history, one round trip
-- ---------------------------------------------------------------------------
EXPLAIN ANALYZE
SELECT c.consultation_id, c.consultation_date, c.diagnosis,
       COUNT(DISTINCT pi.medicine_id) AS medicines,
       COUNT(DISTINCT lo.order_id)    AS lab_tests
FROM consultations c
LEFT JOIN prescriptions      p  ON p.consultation_id  = c.consultation_id
LEFT JOIN prescription_items pi ON pi.prescription_id = p.prescription_id
LEFT JOIN lab_orders         lo ON lo.appointment_id  = c.appointment_id
WHERE c.patient_id = 101
GROUP BY c.consultation_id, c.consultation_date, c.diagnosis
ORDER BY c.consultation_date DESC;
-- WATCH FOR: COUNT(DISTINCT ...) is required here. Two LEFT JOINs multiply the
-- rows (a fan-out), so a plain COUNT(*) would over-count. Classic exam trap.

-- ---------------------------------------------------------------------------
-- (C) MEMBER 3 — monthly financial report: aggregate-on-the-fly vs
--     PRE-AGGREGATED SUMMARY TABLE (materialised view pattern)
-- ---------------------------------------------------------------------------
SET @ym = DATE_FORMAT(CURDATE() - INTERVAL 1 MONTH, '%Y-%m');

-- SLOW PATH — recomputed for every viewer, every time
EXPLAIN ANALYZE
SELECT dep.department_name,
       COUNT(DISTINCT b.bill_id) AS bills,
       SUM(b.total_amount)       AS billed,
       SUM(b.paid_amount)        AS collected
FROM bills b
JOIN appointments a  ON a.appointment_id = b.appointment_id
JOIN doctors      d  ON d.doctor_id      = a.doctor_id
JOIN departments  dep ON dep.department_id = d.department_id
WHERE b.bill_date >= STR_TO_DATE(CONCAT(@ym,'-01'),'%Y-%m-%d')
  AND b.bill_date <  STR_TO_DATE(CONCAT(@ym,'-01'),'%Y-%m-%d') + INTERVAL 1 MONTH
GROUP BY dep.department_name;

-- FAST PATH — computed once by a nightly job, read as a plain PK lookup
CALL sp_refresh_monthly_revenue(@ym);

EXPLAIN ANALYZE
SELECT dep.department_name, m.bill_count, m.total_billed, m.total_paid
FROM monthly_revenue_summary m
JOIN departments dep ON dep.department_id = m.department_id
WHERE m.ym_key = @ym;
-- TRADE-OFF TO STATE OUT LOUD: the summary is STALE between refreshes. You are
-- trading freshness for speed - correct for a month-end report, wrong for a
-- live balance.

-- ---------------------------------------------------------------------------
-- (D) MEMBER 4 — inventory valuation, and a COVERING INDEX
-- ---------------------------------------------------------------------------
EXPLAIN ANALYZE
SELECT m.category,
       SUM(ib.quantity_available)                    AS units,
       SUM(ib.quantity_available * ib.purchase_price) AS stock_value
FROM medicines m
JOIN inventory_batches ib ON ib.medicine_id = m.medicine_id
WHERE ib.expiry_date >= CURDATE()
GROUP BY m.category;

-- Add an index that CONTAINS every column the query touches:
CREATE INDEX idx_batches_covering
    ON inventory_batches (medicine_id, expiry_date, quantity_available, purchase_price);

EXPLAIN
SELECT medicine_id, SUM(quantity_available * purchase_price)
FROM inventory_batches
WHERE expiry_date >= CURDATE()
GROUP BY medicine_id;
-- Extra: "Using index" => the clustered index (the table) is never read at all.
-- COST: this index is now maintained on every stock movement. A covering index
-- speeds up reads and slows down writes - say the trade-off, don't hide it.

-- ---------------------------------------------------------------------------
-- (E) MEMBER 5 — THE COMPLEX AUDIT REPORT  (main L7-L8 demonstration)
-- ---------------------------------------------------------------------------

-- VERSION 1 — the naive report. Three correlated subqueries, each re-scanning
-- audit_logs once per user: roughly O(users x audit rows).
EXPLAIN ANALYZE
SELECT u.user_id, u.username,
       (SELECT COUNT(*) FROM audit_logs a
         WHERE a.user_id = u.user_id AND a.action = 'INSERT') AS inserts,
       (SELECT COUNT(*) FROM audit_logs a
         WHERE a.user_id = u.user_id AND a.action = 'UPDATE') AS updates,
       (SELECT COUNT(*) FROM audit_logs a
         WHERE a.user_id = u.user_id AND a.action = 'DELETE') AS deletes
FROM users u
WHERE u.is_active = TRUE;

-- VERSION 2 — conditional aggregation. audit_logs is read ONCE.
EXPLAIN ANALYZE
SELECT u.user_id, u.username,
       SUM(a.action = 'INSERT') AS inserts,
       SUM(a.action = 'UPDATE') AS updates,
       SUM(a.action = 'DELETE') AS deletes,
       COUNT(a.log_id)          AS total_events
FROM users u
LEFT JOIN audit_logs a ON a.user_id = u.user_id
WHERE u.is_active = TRUE
GROUP BY u.user_id, u.username;

-- VERSION 3 — push the time filter down and let a covering index serve it.
CREATE INDEX idx_audit_user_action_time ON audit_logs (user_id, action, created_at);

EXPLAIN ANALYZE
SELECT u.user_id, u.username,
       SUM(a.action = 'INSERT') AS inserts,
       SUM(a.action = 'UPDATE') AS updates,
       SUM(a.action = 'DELETE') AS deletes
FROM users u
LEFT JOIN audit_logs a
       ON a.user_id = u.user_id
      AND a.created_at >= NOW() - INTERVAL 30 DAY     -- in the JOIN, not the WHERE
WHERE u.is_active = TRUE
GROUP BY u.user_id, u.username;
-- IMPORTANT SEMANTIC POINT: on a LEFT JOIN, a condition in WHERE throws away
-- the unmatched rows and silently turns it into an INNER JOIN. Putting the
-- date filter in the ON clause keeps users with zero recent activity.

-- Windowed "top 10 busiest days" without any self-join:
EXPLAIN ANALYZE
SELECT day, events, running_total FROM (
    SELECT DATE(created_at) AS day,
           COUNT(*)         AS events,
           SUM(COUNT(*)) OVER (ORDER BY DATE(created_at)) AS running_total
    FROM audit_logs
    WHERE created_at >= NOW() - INTERVAL 90 DAY
    GROUP BY DATE(created_at)
) t
ORDER BY events DESC
LIMIT 10;

-- ---------------------------------------------------------------------------
-- OPTIMIZER TRANSPARENCY — nice closing move in the viva
-- ---------------------------------------------------------------------------
EXPLAIN FORMAT=JSON
SELECT a.appointment_id, p.first_name, d.last_name
FROM appointments a
JOIN patients p ON p.patient_id = a.patient_id
JOIN doctors  d ON d.doctor_id  = a.doctor_id
WHERE a.appointment_date = CURDATE() + INTERVAL 1 DAY;
-- Read "cost_info" -> these are the numbers the cost-based optimizer compares
-- when it picks a join order. It is arithmetic, not magic.

-- ---------------------------------------------------------------------------
-- CLEAN UP the file-organization demo tables (keep the real indexes)
-- ---------------------------------------------------------------------------
-- DROP TABLE IF EXISTS fo_heap, fo_ordered, fo_hash;

-- END OF FILE 07


-- ############################################################################
-- ##  STAGE 9  --  08_serializability_concurrency_L11_L13.sql
-- ############################################################################

-- ============================================================================
--  FILE 08 of 08 : VIEW SERIALIZABILITY (L11)
--                  CONCURRENCY CONTROL   (L12 - L13)
-- ============================================================================
--  HOW TO RUN THIS FILE
--  Open TWO (for the deadlock demo, THREE) query tabs in MySQL Workbench.
--  Each tab is an independent SESSION = an independent TRANSACTION.
--  Blocks below are marked  >>> SESSION A <<<  /  >>> SESSION B <<<  and are
--  numbered  [A1] [B1] [A2] ...  -> run them in that number order, alternating
--  tabs. Do NOT paste a whole block at once: the whole point is the pause.
--
--  Check first that both tabs are on the same database and that Workbench is
--  NOT auto-committing your explicit transactions:
--      SELECT DATABASE(), CONNECTION_ID(), @@autocommit, @@transaction_isolation;
-- ============================================================================

USE hospital_management;

-- ############################################################################
-- ############################################################################
--  L11 : VIEW SERIALIZABILITY     *** MEMBER 5 IS THE MAIN DEMONSTRATOR ***
-- ############################################################################
-- ############################################################################
--
--  DEFINITIONS (say these first, in this order):
--
--  SCHEDULE            an interleaving of the operations of several transactions.
--  SERIAL SCHEDULE     transactions run one completely after another. Correct
--                      by definition.
--  CONFLICTING OPS     two operations conflict if they are from DIFFERENT
--                      transactions, on the SAME data item, and at least one
--                      is a WRITE.  (R-W, W-R, W-W conflict; R-R never does.)
--  CONFLICT SERIALIZABLE
--                      can be turned into a serial schedule by swapping only
--                      NON-conflicting adjacent operations.
--                      TEST: build the precedence graph. Acyclic <=> yes.
--  VIEW SERIALIZABLE   view-equivalent to some serial schedule, i.e. all three
--                      hold:
--                        (1) same transaction reads the INITIAL value of each item
--                        (2) same "reads-from" pairs
--                        (3) same transaction performs the FINAL write of each item
--
--  RELATIONSHIP:  every conflict-serializable schedule is view-serializable.
--                 The reverse is FALSE, and the counter-example always involves
--                 a BLIND WRITE (a write with no prior read by that same
--                 transaction). We reproduce exactly that below.
--
--  Data item  A  =  doctors.consultation_fee  WHERE doctor_id = 1
-- ----------------------------------------------------------------------------

TRUNCATE TABLE txn_schedule_log;
UPDATE doctors SET consultation_fee = 1000.00 WHERE doctor_id = 1;   -- initial A = 1000

SELECT consultation_fee AS A_initial FROM doctors WHERE doctor_id = 1;

-- ----------------------------------------------------------------------------
--  THE SCHEDULE WE WILL PRODUCE
--
--      S :  r1(A)   w2(A)   w1(A)   w3(A)
--
--      T1 : READ A, then WRITE A
--      T2 : WRITE A            (blind write - never read A)
--      T3 : WRITE A            (blind write - never read A)
--
--  Run the steps in the number order [A1] [B1] [B2] [A2] [A3] [C1] [C2].
-- ----------------------------------------------------------------------------

-- >>> SESSION A  (= T1) <<< ---------------------------------------------------
-- [A1]
START TRANSACTION;
SELECT consultation_fee INTO @a_read FROM doctors WHERE doctor_id = 1;   -- r1(A)
INSERT INTO txn_schedule_log (txn_name, operation, data_item, value_seen, note)
VALUES ('T1','READ','A', @a_read, 'T1 reads the initial value of A');
SELECT @a_read AS T1_saw;
-- >>> now switch to SESSION B, leave this transaction OPEN <<<

-- >>> SESSION B  (= T2) <<< ---------------------------------------------------
-- [B1]
START TRANSACTION;
UPDATE doctors SET consultation_fee = 3000.00 WHERE doctor_id = 1;       -- w2(A)
INSERT INTO txn_schedule_log (txn_name, operation, data_item, value_seen, note)
VALUES ('T2','WRITE','A', 3000.00, 'BLIND WRITE - T2 never read A');
-- [B2]
COMMIT;
INSERT INTO txn_schedule_log (txn_name, operation, data_item)
VALUES ('T2','COMMIT', NULL);
-- >>> back to SESSION A <<<

-- >>> SESSION A  (= T1) <<< ---------------------------------------------------
-- [A2]  T1 now writes, based on the value it read in [A1] - i.e. it overwrites
--       what T2 just committed.
UPDATE doctors SET consultation_fee = @a_read + 500 WHERE doctor_id = 1;  -- w1(A)
INSERT INTO txn_schedule_log (txn_name, operation, data_item, value_seen, note)
VALUES ('T1','WRITE','A', @a_read + 500, 'T1 writes read_value + 500');
-- [A3]
COMMIT;
INSERT INTO txn_schedule_log (txn_name, operation, data_item)
VALUES ('T1','COMMIT', NULL);

-- >>> SESSION C  (= T3)  (a third tab, or reuse SESSION B) <<< ----------------
-- [C1]
START TRANSACTION;
UPDATE doctors SET consultation_fee = 5000.00 WHERE doctor_id = 1;       -- w3(A)
INSERT INTO txn_schedule_log (txn_name, operation, data_item, value_seen, note)
VALUES ('T3','WRITE','A', 5000.00, 'BLIND WRITE - final writer');
-- [C2]
COMMIT;
INSERT INTO txn_schedule_log (txn_name, operation, data_item)
VALUES ('T3','COMMIT', NULL);

-- ----------------------------------------------------------------------------
--  ANALYSIS 1 — the schedule that actually happened
-- ----------------------------------------------------------------------------
SELECT seq_no, txn_name, operation, data_item, value_seen, note
FROM txn_schedule_log ORDER BY seq_no;

SELECT consultation_fee AS A_final FROM doctors WHERE doctor_id = 1;   -- 5000 (T3)

-- ----------------------------------------------------------------------------
--  ANALYSIS 2 — build the PRECEDENCE GRAPH straight from the log.
--  An edge Ti -> Tj exists when Ti's operation comes first, they touch the same
--  item, they are different transactions, and at least one is a WRITE.
-- ----------------------------------------------------------------------------
SELECT DISTINCT
       CONCAT(e1.txn_name, ' -> ', e2.txn_name) AS edge,
       CONCAT(LOWER(LEFT(e1.operation,1)), '(', e1.data_item, ') then ',
              LOWER(LEFT(e2.operation,1)), '(', e2.data_item, ')') AS because
FROM txn_schedule_log e1
JOIN txn_schedule_log e2
  ON e2.seq_no   > e1.seq_no
 AND e2.data_item = e1.data_item
 AND e2.txn_name <> e1.txn_name
WHERE e1.operation IN ('READ','WRITE')
  AND e2.operation IN ('READ','WRITE')
  AND (e1.operation = 'WRITE' OR e2.operation = 'WRITE')
ORDER BY edge;
--
--  EXPECTED EDGES:
--      T1 -> T2   because r1(A) then w2(A)      (Read-Write conflict)
--      T2 -> T1   because w2(A) then w1(A)      (Write-Write conflict)
--      T1 -> T3, T2 -> T3                        (both write before w3)
--
--  T1 -> T2 AND T2 -> T1 is a CYCLE.
--  ==> S is NOT CONFLICT SERIALIZABLE.

-- ----------------------------------------------------------------------------
--  ANALYSIS 3 — but is it VIEW SERIALIZABLE?  Test against serial S' = T1,T2,T3
--
--   (1) INITIAL READ : in S, T1 reads the initial A (1000).
--                      in S', T1 runs first, so T1 also reads the initial A.  OK
--   (2) READS-FROM   : T2 and T3 never read anything, so there are no
--                      reads-from pairs to preserve in either schedule.        OK
--   (3) FINAL WRITE  : in S the last write on A is w3(A).
--                      in S' the last transaction is T3, so T3 writes last.    OK
--
--   All three conditions hold  ==>  S IS VIEW SERIALIZABLE.
--
--   CONCLUSION TO STATE:
--   "S is view-serializable but NOT conflict-serializable. The only reason it
--    is acceptable is the blind writes by T2 and T3: their values are thrown
--    away by the final writer, so the intermediate conflict cycle has no
--    observable effect. Real database engines, including InnoDB, only enforce
--    CONFLICT serializability, because testing view serializability is an
--    NP-complete problem. So a correct schedule like this one is one that a
--    real DBMS would still refuse to produce under SERIALIZABLE isolation."
-- ----------------------------------------------------------------------------

-- ----------------------------------------------------------------------------
--  CONTRAST CASE — a schedule that IS conflict serializable (acyclic graph)
--      S2 :  r1(A) w1(A) r2(A) w2(A)     ->  edges only T1 -> T2
-- ----------------------------------------------------------------------------
TRUNCATE TABLE txn_schedule_log;
INSERT INTO txn_schedule_log (txn_name, operation, data_item, value_seen) VALUES
 ('T1','READ','A',1000), ('T1','WRITE','A',1500),
 ('T2','READ','A',1500), ('T2','WRITE','A',2000);

SELECT DISTINCT CONCAT(e1.txn_name,' -> ',e2.txn_name) AS edge
FROM txn_schedule_log e1
JOIN txn_schedule_log e2
  ON e2.seq_no > e1.seq_no AND e2.data_item = e1.data_item AND e2.txn_name <> e1.txn_name
WHERE (e1.operation = 'WRITE' OR e2.operation = 'WRITE');
-- Only  T1 -> T2 . No cycle => conflict serializable => equivalent to T1 then T2.

-- ############################################################################
-- ############################################################################
--  L12 - L13 : CONCURRENCY CONTROL   *** MEMBER 4 IS THE MAIN DEMONSTRATOR ***
-- ############################################################################
-- ############################################################################
--
--  The four classic anomalies, and which isolation level prevents each:
--
--    ANOMALY              READ UNCOMMITTED  READ COMMITTED  REPEATABLE READ  SERIALIZABLE
--    Dirty read                possible        prevented       prevented       prevented
--    Non-repeatable read       possible        possible        prevented       prevented
--    Phantom read              possible        possible        prevented*      prevented
--    Lost update               possible        possible        possible**      prevented
--
--    *  InnoDB prevents phantoms in REPEATABLE READ using NEXT-KEY LOCKS
--       (record lock + gap lock). Most textbooks say RR allows phantoms; InnoDB
--       is stronger than the standard. Mention both - examiners like that.
--    ** A lost update is an APPLICATION-level race (read, think, write). No
--       isolation level below SERIALIZABLE stops it. You stop it yourself with
--       SELECT ... FOR UPDATE or with a version column.
--
--  MySQL's default is REPEATABLE READ:
SELECT @@transaction_isolation AS default_isolation;

-- ============================================================================
--  DEMO 1 — LOST UPDATE, and the fix.        (MEMBER 3: same bill, 2 cashiers)
-- ============================================================================
-- Set up a bill with a known balance
SELECT bill_id INTO @B FROM bills WHERE status = 'Pending' ORDER BY bill_id LIMIT 1;
SELECT @B AS demo_bill, total_amount, paid_amount, balance_amount
  FROM bills WHERE bill_id = @B;

-- ---------- 1a : THE BUG (plain SELECT = non-locking MVCC read) --------------
-- >>> SESSION A <<<
-- [A1]
START TRANSACTION;
SELECT total_amount - paid_amount INTO @bal_a FROM bills WHERE bill_id = @B;  -- no lock
SELECT @bal_a AS session_A_thinks_balance_is;

-- >>> SESSION B <<<
-- [B1]
START TRANSACTION;
SELECT total_amount - paid_amount INTO @bal_b FROM bills WHERE bill_id = @B;  -- no lock
SELECT @bal_b AS session_B_thinks_balance_is;
-- Both sessions read the SAME balance. Both are about to accept a full payment.

-- >>> SESSION A <<<
-- [A2]
INSERT INTO payments (bill_id, amount, payment_method, received_by)
VALUES (@B, @bal_a, 'Cash', 'Cashier-A');
COMMIT;

-- >>> SESSION B <<<
-- [B2]
INSERT INTO payments (bill_id, amount, payment_method, received_by)
VALUES (@B, @bal_b, 'Card', 'Cashier-B');
-- EXPECTED: ERROR 1644 'Payment exceeds the outstanding balance of this bill'
--           (or, without the trigger, ERROR 3819 on chk_bill_no_overpay)
COMMIT;

-- SAY THIS: the constraint SAVED us, but only by crashing the second cashier
-- after they already told the patient the payment went through. A constraint is
-- a last line of defence, not a concurrency strategy. Now do it properly:

-- ---------- 1b : THE FIX (pessimistic lock) ---------------------------------
SELECT bill_id INTO @B2 FROM bills WHERE status = 'Pending' ORDER BY bill_id LIMIT 1;

-- >>> SESSION A <<<
-- [A1]
START TRANSACTION;
SELECT total_amount - paid_amount INTO @bal_a
  FROM bills WHERE bill_id = @B2 FOR UPDATE;     -- X-lock held until COMMIT

-- >>> SESSION B <<<
-- [B1]
START TRANSACTION;
SELECT total_amount - paid_amount INTO @bal_b
  FROM bills WHERE bill_id = @B2 FOR UPDATE;
-- >>> SESSION B NOW HANGS. That pause IS the concurrency control. <<<
-- While it hangs, run this in a THIRD tab to see the lock:
--     SELECT * FROM performance_schema.data_locks WHERE OBJECT_NAME = 'bills';
--     SELECT * FROM sys.innodb_lock_waits;

-- >>> SESSION A <<<
-- [A2]
INSERT INTO payments (bill_id, amount, payment_method, received_by)
VALUES (@B2, @bal_a, 'Cash', 'Cashier-A');
COMMIT;                       -- <- SESSION B unblocks the instant this runs

-- >>> SESSION B <<<
-- [B2]  B's SELECT now returns the FRESH balance (0), so B correctly refuses.
SELECT @bal_b AS session_B_now_sees;      -- 0.00
ROLLBACK;

-- ---------- 1c : THE OTHER FIX (optimistic locking, no waiting) -------------
-- Better when conflicts are RARE: don't lock, but refuse to write if the row
-- changed under you. ROW_COUNT() = 0 means "somebody beat me, retry".
-- >>> SESSION A <<<
START TRANSACTION;
SELECT row_version INTO @v FROM bills WHERE bill_id = @B2;
-- ... application thinks ...
UPDATE bills SET discount = discount + 0, row_version = row_version + 1
 WHERE bill_id = @B2 AND row_version = @v;
SELECT ROW_COUNT() AS rows_updated;   -- 1 = I won, 0 = someone else won, retry
COMMIT;
-- PESSIMISTIC = "lock first, never fail".  OPTIMISTIC = "never wait, maybe retry".
-- Choose by conflict rate: high contention -> pessimistic; low -> optimistic.

-- ============================================================================
--  DEMO 2 — DIRTY READ: possible in theory, and what InnoDB actually does
-- ============================================================================
-- >>> SESSION A <<<
-- [A1]
START TRANSACTION;
UPDATE doctors SET consultation_fee = 99999.00 WHERE doctor_id = 2;  -- NOT committed

-- >>> SESSION B <<<
-- [B1]
SET SESSION TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
START TRANSACTION;
SELECT consultation_fee AS dirty_value FROM doctors WHERE doctor_id = 2;
-- Shows 99999 - a value that does not exist in any committed state. DIRTY READ.

-- [B2]
SET SESSION TRANSACTION ISOLATION LEVEL REPEATABLE READ;
COMMIT;
START TRANSACTION;
SELECT consultation_fee AS clean_value FROM doctors WHERE doctor_id = 2;
-- Shows the OLD committed value. MVCC gives B a consistent snapshot.

-- >>> SESSION A <<<
-- [A2]
ROLLBACK;   -- the 99999 never existed. Session B would have acted on a phantom value.

-- ============================================================================
--  DEMO 3 — NON-REPEATABLE READ : READ COMMITTED vs REPEATABLE READ
-- ============================================================================
-- >>> SESSION A <<<
-- [A1]
SET SESSION TRANSACTION ISOLATION LEVEL READ COMMITTED;
START TRANSACTION;
SELECT consultation_fee AS first_read FROM doctors WHERE doctor_id = 3;

-- >>> SESSION B <<<
-- [B1]
UPDATE doctors SET consultation_fee = consultation_fee + 100 WHERE doctor_id = 3;  -- autocommit

-- >>> SESSION A <<<
-- [A2]
SELECT consultation_fee AS second_read FROM doctors WHERE doctor_id = 3;
-- DIFFERENT from first_read, inside ONE transaction => NON-REPEATABLE READ
COMMIT;

-- [A3] Repeat the whole thing under REPEATABLE READ
SET SESSION TRANSACTION ISOLATION LEVEL REPEATABLE READ;
START TRANSACTION;
SELECT consultation_fee AS first_read FROM doctors WHERE doctor_id = 3;
--   >>> SESSION B: UPDATE doctors SET consultation_fee = consultation_fee + 100
--                   WHERE doctor_id = 3;
SELECT consultation_fee AS second_read FROM doctors WHERE doctor_id = 3;
-- IDENTICAL. The snapshot was fixed at the first read. That is MVCC.
COMMIT;

-- ============================================================================
--  DEMO 4 — PHANTOM READ and NEXT-KEY (GAP) LOCKS
-- ============================================================================
-- >>> SESSION A <<<
-- [A1]
START TRANSACTION;
SELECT COUNT(*) AS phantom_count FROM appointments
 WHERE doctor_id = 9 AND appointment_date = CURDATE() + INTERVAL 60 DAY
 FOR UPDATE;                       -- locking read -> takes a GAP lock on the range

-- >>> SESSION B <<<
-- [B1]
START TRANSACTION;
INSERT INTO appointments (patient_id, doctor_id, appointment_date, appointment_time, status)
VALUES (200, 9, CURDATE() + INTERVAL 60 DAY, '11:00:00', 'Scheduled');
-- >>> BLOCKS. The gap lock from A stops a new row appearing inside a range that
--     A has already examined. That is how InnoDB kills phantoms in RR. <<<

-- >>> SESSION A <<<
-- [A2]
SELECT COUNT(*) AS phantom_count_again FROM appointments
 WHERE doctor_id = 9 AND appointment_date = CURDATE() + INTERVAL 60 DAY;
COMMIT;      -- B now proceeds

-- >>> SESSION B <<<
-- [B2]
COMMIT;

-- ============================================================================
--  DEMO 5 — DOUBLE BOOKING          *** MEMBER 1's CONCURRENCY SCENARIO ***
--  Two receptionists book the SAME doctor, SAME date, SAME time.
-- ============================================================================
SET @slot_date = CURDATE() + INTERVAL 50 DAY;

-- >>> SESSION A <<<
-- [A1]
START TRANSACTION;
SELECT doctor_id FROM doctors WHERE doctor_id = 11 FOR UPDATE;
SELECT COUNT(*) AS taken FROM appointments
 WHERE doctor_id = 11 AND appointment_date = @slot_date AND appointment_time = '10:00:00'
   AND status IN ('Scheduled','Confirmed');                        -- 0 -> looks free

-- >>> SESSION B <<<
-- [B1]
START TRANSACTION;
SELECT doctor_id FROM doctors WHERE doctor_id = 11 FOR UPDATE;
-- >>> BLOCKS on A's lock on the doctor row <<<

-- >>> SESSION A <<<
-- [A2]
INSERT INTO appointments (patient_id, doctor_id, appointment_date, appointment_time, status, reason)
VALUES (301, 11, @slot_date, '10:00:00', 'Scheduled', 'Receptionist A');
COMMIT;                                        -- B unblocks here

-- >>> SESSION B <<<
-- [B2]
SELECT COUNT(*) AS taken FROM appointments
 WHERE doctor_id = 11 AND appointment_date = @slot_date AND appointment_time = '10:00:00'
   AND status IN ('Scheduled','Confirmed');    -- now 1 -> B correctly stops

-- [B3] and even if B ignores the check, the engine refuses:
INSERT INTO appointments (patient_id, doctor_id, appointment_date, appointment_time, status, reason)
VALUES (302, 11, @slot_date, '10:00:00', 'Scheduled', 'Receptionist B');
-- EXPECTED: ERROR 1062 Duplicate entry for key 'uq_active_slot'
ROLLBACK;

-- Through the procedure, the same race gives a clean business error:
CALL sp_book_or_reschedule_appointment(@ap, 302, 11, @slot_date, '10:00:00', 'via SP');
-- EXPECTED: ERROR 1644 'SLOT ALREADY BOOKED: another user took this doctor/date/time'

-- ============================================================================
--  DEMO 6 — CONCURRENT DISPENSING   *** MEMBER 4's MAIN L12-L13 SCENARIO ***
--  Two pharmacists dispense from the same batch at the same moment.
-- ============================================================================
-- Prepare a batch holding exactly 100 units
SELECT batch_id INTO @bt FROM inventory_batches
 WHERE expiry_date >= CURDATE() + INTERVAL 60 DAY ORDER BY batch_id LIMIT 1;
UPDATE inventory_batches SET quantity_available = 100 WHERE batch_id = @bt;
SELECT @bt AS demo_batch, quantity_available FROM inventory_batches WHERE batch_id = @bt;

-- ---------- 6a : WITHOUT LOCKING (the race) ---------------------------------
-- >>> SESSION A <<<        >>> SESSION B <<<
-- [A1] START TRANSACTION;
--      SELECT quantity_available INTO @qa FROM inventory_batches WHERE batch_id = @bt;
--                          -- [B1] START TRANSACTION;
--                          --      SELECT quantity_available INTO @qb ... (same 100)
-- [A2] INSERT INTO stock_transactions ... 'Dispense', 80 ...
--                          -- [B2] INSERT INTO stock_transactions ... 'Dispense', 80 ...
-- Both believed 100 were available; together they take 160.
-- The CHECK/trigger stops the second one:
--     ERROR 1644 'STOCK CANNOT GO NEGATIVE: dispense rejected'
-- Correct outcome, but again only by failing late.

-- ---------- 6b : WITH LOCKING (the design) ----------------------------------
-- >>> SESSION A <<<
-- [A1]
START TRANSACTION;
SELECT quantity_available INTO @qa
  FROM inventory_batches WHERE batch_id = @bt FOR UPDATE;    -- X-lock
SELECT @qa AS A_sees;

-- >>> SESSION B <<<
-- [B1]
START TRANSACTION;
SELECT quantity_available INTO @qb
  FROM inventory_batches WHERE batch_id = @bt FOR UPDATE;
-- >>> BLOCKS until A commits <<<

-- >>> SESSION A <<<
-- [A2]
INSERT INTO stock_transactions (batch_id, medicine_id, transaction_type, quantity, performed_by)
SELECT @bt, medicine_id, 'Dispense', 80, 'Pharmacist-A'
  FROM inventory_batches WHERE batch_id = @bt;
COMMIT;

-- >>> SESSION B <<<
-- [B2]  B's SELECT returns 20, not 100. B now dispenses only what exists.
SELECT @qb AS B_sees_after_unblocking;      -- 20
INSERT INTO stock_transactions (batch_id, medicine_id, transaction_type, quantity, performed_by)
SELECT @bt, medicine_id, 'Dispense', 80, 'Pharmacist-B'
  FROM inventory_batches WHERE batch_id = @bt;
-- EXPECTED: ERROR 1644 'STOCK CANNOT GO NEGATIVE: dispense rejected'
ROLLBACK;

-- Non-blocking variants (MySQL 8.0) — worth one sentence each:
-- SELECT ... FOR UPDATE NOWAIT;       fail immediately instead of waiting
-- SELECT ... FOR UPDATE SKIP LOCKED;  skip locked rows - ideal for a work queue,
--                                     e.g. two lab techs pulling pending orders:
START TRANSACTION;
SELECT order_id, priority FROM lab_orders
 WHERE status = 'Pending' ORDER BY priority, order_date
 LIMIT 5 FOR UPDATE SKIP LOCKED;
COMMIT;

-- ============================================================================
--  DEMO 7 — CONCURRENT LAB RESULT ENTRY      *** MEMBER 2's SCENARIO ***
--  Two technicians type the result for the same order.
-- ============================================================================
SELECT order_id INTO @ord FROM lab_orders WHERE status = 'Pending' ORDER BY order_id LIMIT 1;

-- >>> SESSION A <<<
START TRANSACTION;
INSERT INTO lab_results (order_id, result_value, performed_by) VALUES (@ord, '12.1', 'Tech-A');
-- (not committed yet)

-- >>> SESSION B <<<
START TRANSACTION;
INSERT INTO lab_results (order_id, result_value, performed_by) VALUES (@ord, '9.8', 'Tech-B');
-- >>> BLOCKS. InnoDB holds a lock on the not-yet-committed UNIQUE key value. <<<

-- >>> SESSION A <<<  COMMIT;
-- >>> SESSION B <<<  now fails: ERROR 1062 Duplicate entry for key 'uq_lab_result_order'
--                    ROLLBACK;
-- A duplicate lab result is a patient-safety issue, not just a data issue.
-- UNIQUE(order_id) makes it impossible rather than unlikely.

-- ============================================================================
--  DEMO 8 — DEADLOCK: cause it, read it, prevent it
-- ============================================================================
SELECT bill_id INTO @d1 FROM bills ORDER BY bill_id LIMIT 1;
SELECT bill_id INTO @d2 FROM bills ORDER BY bill_id DESC LIMIT 1;

-- >>> SESSION A <<<
-- [A1]
START TRANSACTION;
UPDATE bills SET discount = discount WHERE bill_id = @d1;   -- locks row d1

-- >>> SESSION B <<<
-- [B1]
START TRANSACTION;
UPDATE bills SET discount = discount WHERE bill_id = @d2;   -- locks row d2

-- >>> SESSION A <<<
-- [A2]
UPDATE bills SET discount = discount WHERE bill_id = @d2;   -- waits for B

-- >>> SESSION B <<<
-- [B2]
UPDATE bills SET discount = discount WHERE bill_id = @d1;   -- waits for A -> CYCLE
-- EXPECTED in ONE of the two sessions:
--   ERROR 1213 (40001): Deadlock found when trying to get lock; try restarting transaction

-- InnoDB detects the cycle in its wait-for graph and kills the cheaper victim.
-- Inspect it:
SHOW ENGINE INNODB STATUS;          -- read the "LATEST DETECTED DEADLOCK" section
SELECT * FROM performance_schema.data_lock_waits;
SHOW STATUS LIKE 'Innodb_deadlocks';

-- >>> whichever session survived <<<
COMMIT;
-- >>> the victim <<<
ROLLBACK;

-- PREVENTION — three rules to state in the viva:
--   1. Always take locks in the SAME ORDER everywhere (e.g. ascending bill_id).
--      A deadlock needs a cycle; a global ordering makes cycles impossible.
--   2. Keep transactions SHORT. No user input, no network calls while holding locks.
--   3. Deadlocks are normal under load - the application must CATCH 1213 and
--      RETRY, not treat it as a fatal error.

-- Rule 1 in code — both sessions lock in ascending id order, so no cycle:
START TRANSACTION;
SELECT bill_id FROM bills
 WHERE bill_id IN (@d1, @d2)
 ORDER BY bill_id                     -- <-- the deterministic ordering
 FOR UPDATE;
COMMIT;

-- ============================================================================
--  LOCK-INSPECTION CHEAT SHEET (keep this open in a third tab during the viva)
-- ============================================================================
-- SELECT * FROM performance_schema.data_locks;        -- what is locked, and how
-- SELECT * FROM performance_schema.data_lock_waits;   -- who waits for whom
-- SELECT * FROM sys.innodb_lock_waits;                -- readable summary
-- SELECT trx_id, trx_state, trx_started, trx_mysql_thread_id, trx_query
--   FROM information_schema.innodb_trx;               -- live transactions
-- SHOW PROCESSLIST;                                   -- sessions and their state
-- KILL <id>;                                          -- release a stuck demo

-- END OF FILE 08


-- ############################################################################
-- ##  END OF COMPLETE SCRIPT
-- ##
-- ##  Everything the requirement sheet asks for is in this one file:
-- ##    25 tables, 15 functions, 15 views, 15 procedures, 15 triggers,
-- ##    15 indexes, 10 transactions, and the L1-L13 demonstrations.
-- ##
-- ##  Object-by-object mapping to the requirement sheet is in
-- ##  REQUIREMENTS_COVERAGE.md
-- ############################################################################
