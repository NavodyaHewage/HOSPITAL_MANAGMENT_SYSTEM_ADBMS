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
