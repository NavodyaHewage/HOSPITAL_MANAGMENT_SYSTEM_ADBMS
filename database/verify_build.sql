-- ============================================================================
--  QUICK BUILD VERIFICATION
--  Run any time after 99_COMPLETE_HOSPITAL_DB.sql to confirm Part A is intact:
--      mysql -u root -p < database/verify_build.sql
--  Every row must say PASS.
-- ============================================================================
USE hospital_management;

SELECT 'Base tables' AS object_type, COUNT(*) AS actual, 25 AS required,
       IF(COUNT(*) = 25,'PASS','FAIL') AS result
FROM information_schema.TABLES
WHERE TABLE_SCHEMA='hospital_management' AND TABLE_TYPE='BASE TABLE'
  AND TABLE_NAME NOT IN ('seq_numbers','monthly_revenue_summary','txn_schedule_log')
UNION ALL
SELECT 'Views', COUNT(*), 15, IF(COUNT(*)=15,'PASS','FAIL')
FROM information_schema.VIEWS WHERE TABLE_SCHEMA='hospital_management'
UNION ALL
SELECT 'Functions', COUNT(*), 15, IF(COUNT(*)=15,'PASS','FAIL')
FROM information_schema.ROUTINES
WHERE ROUTINE_SCHEMA='hospital_management' AND ROUTINE_TYPE='FUNCTION'
UNION ALL
SELECT 'Procedures', COUNT(*), 16, IF(COUNT(*)=16,'PASS','FAIL')
FROM information_schema.ROUTINES
WHERE ROUTINE_SCHEMA='hospital_management' AND ROUTINE_TYPE='PROCEDURE'
UNION ALL
SELECT 'Triggers', COUNT(*), 15, IF(COUNT(*)=15,'PASS','FAIL')
FROM information_schema.TRIGGERS WHERE TRIGGER_SCHEMA='hospital_management'
UNION ALL
SELECT 'Secondary indexes', COUNT(DISTINCT INDEX_NAME), 15,
       IF(COUNT(DISTINCT INDEX_NAME)=15,'PASS','FAIL')
FROM information_schema.STATISTICS
WHERE TABLE_SCHEMA='hospital_management' AND INDEX_NAME LIKE 'idx_%';

-- The trigger that was missing last time. Must return exactly 1.
SELECT COUNT(*) AS trg_users_au_session_exists
FROM information_schema.TRIGGERS
WHERE TRIGGER_SCHEMA='hospital_management' AND TRIGGER_NAME='trg_users_au_session';

-- Row counts: proves the seed loaded.
SELECT 'appointments' AS tbl, COUNT(*) AS rows_loaded FROM appointments
UNION ALL SELECT 'patients', COUNT(*) FROM patients
UNION ALL SELECT 'bills',    COUNT(*) FROM bills
UNION ALL SELECT 'payments', COUNT(*) FROM payments
UNION ALL SELECT 'audit_logs', COUNT(*) FROM audit_logs;
