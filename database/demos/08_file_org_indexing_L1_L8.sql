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
--
-- WHY THE PLAIN "DROP INDEX" FAILS HERE (good viva point):
--   ALTER TABLE appointments DROP INDEX idx_appointments_doctor_datetime;
--   -> ERROR 1553 (HY000): Cannot drop index ...: needed in a foreign key constraint
--
-- When CREATE TABLE declared fk_appt_doctor, InnoDB auto-created a hidden index
-- on (doctor_id) to enforce it. Creating idx_appointments_doctor_datetime, whose
-- LEFTMOST column is doctor_id, made that hidden index redundant, so InnoDB
-- dropped it and let the FK ride on our composite index instead. (Run
-- SHOW INDEX FROM appointments; there is no fk_appt_doctor index any more.)
-- Every FK must keep an index, so the composite can no longer be dropped alone.
--
-- To run an honest BEFORE/AFTER, drop the constraint first and put it back after.
ALTER TABLE appointments DROP FOREIGN KEY fk_appt_doctor;
ALTER TABLE appointments DROP INDEX  idx_appointments_doctor_datetime;

EXPLAIN SELECT appointment_id, patient_id, appointment_time, status
  FROM appointments
 WHERE doctor_id = 7
   AND appointment_date BETWEEN CURDATE() AND CURDATE() + INTERVAL 7 DAY;
-- BEFORE: type=ALL, rows ~ 50000

CREATE INDEX idx_appointments_doctor_datetime
    ON appointments (doctor_id, appointment_date, appointment_time);

-- Re-add the FK only AFTER the composite index exists, so InnoDB reuses it
-- instead of creating a second, redundant index on (doctor_id).
ALTER TABLE appointments
    ADD CONSTRAINT fk_appt_doctor FOREIGN KEY (doctor_id)
        REFERENCES doctors(doctor_id) ON DELETE RESTRICT;

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
-- Both queries below also pin doctor_id. That is deliberate: our only index on
-- appointment_date is the COMPOSITE (doctor_id, appointment_date,
-- appointment_time), and a composite B+Tree is only seekable from its LEFTMOST
-- column. Filtering on appointment_date alone can never produce a range scan
-- here no matter how it is written, so a bare-date before/after would show no
-- difference and would prove nothing. Fix the leftmost column, then vary only
-- the thing under test.
--
-- SLOW: YEAR() wraps the indexed column, so appointment_date cannot be used for
--       seeking. The index is entered on doctor_id only and every one of that
--       doctor's rows is then evaluated.  ->  type=ref, key_len=4
EXPLAIN SELECT COUNT(*) FROM appointments
 WHERE doctor_id = 7
   AND YEAR(appointment_date) = YEAR(CURDATE());

-- FAST: same answer, rewritten as a RANGE on the bare column, so the second
--       index column is usable too.                ->  type=range, key_len=7
EXPLAIN SELECT COUNT(*) FROM appointments
 WHERE doctor_id = 7
   AND appointment_date >= MAKEDATE(YEAR(CURDATE()), 1)
   AND appointment_date <  MAKEDATE(YEAR(CURDATE()) + 1, 1);
-- RULE: keep the indexed column BARE on the left-hand side of the comparison.
-- Watch key_len grow from 4 to 7: that is the optimizer telling you exactly how
-- many columns of the composite index it managed to use.

-- ---------------------------------------------------------------------------
-- (2) LEADING-WILDCARD LIKE
-- ---------------------------------------------------------------------------
CREATE INDEX idx_patients_phone ON patients (phone);   -- the demo needs one

-- NOTE: both queries select first_name, which is NOT in idx_patients_phone.
-- With "SELECT patient_id" alone the index covers the query, so MySQL happily
-- scans the whole INDEX (type=index) in both cases and the contrast disappears.
-- Selecting an uncovered column forces the real choice: seek, or scan the table.
EXPLAIN SELECT patient_id, first_name FROM patients
 WHERE phone LIKE '%1234';       -- type = ALL    : full table scan

EXPLAIN SELECT patient_id, first_name FROM patients
 WHERE phone LIKE '07030000%';   -- type = range  : ~99 rows
-- A B+Tree is ordered by PREFIX. '%x' has no prefix to seek on.
-- The prefix also has to be SELECTIVE: every seeded phone starts '07030',
-- so LIKE '0703%' matches all 5,000 patients and the optimizer correctly
-- ignores the index. "Indexed" and "worth using" are not the same thing.

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
