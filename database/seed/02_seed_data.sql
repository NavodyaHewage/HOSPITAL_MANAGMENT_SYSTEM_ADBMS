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
--
--  AND IT IS NOT MERELY AN OPTIMISATION - THE ORDER IS MANDATORY.
--  Several bulk loads here are of the form
--      INSERT INTO stock_transactions ... SELECT ... FROM inventory_batches
--      INSERT INTO lab_results        ... SELECT ... FROM lab_orders
--      INSERT INTO payments           ... SELECT ... FROM bills
--  Each of those target tables has an AFTER INSERT trigger that UPDATEs the very
--  table being read. Once the triggers exist, MySQL rejects the whole statement:
--      ERROR 1442 (HY000): Can't update table 'bills' in stored function/trigger
--      because it is already used by statement which invoked this ... trigger
--  So: NEVER re-run this file against a database that already has file 05
--  loaded. Re-run the master build (which drops and recreates the schema)
--  instead. Interactive code must read the value into a variable first and then
--  INSERT ... VALUES - see the transaction demos in file 07 for that pattern.
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
