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
