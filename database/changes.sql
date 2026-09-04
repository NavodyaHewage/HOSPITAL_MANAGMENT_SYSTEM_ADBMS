-- ============================================================================
--  changes.sql — incremental migration for an EXISTING hospital_management DB
-- ============================================================================
--  WHEN TO USE THIS FILE
--  Only if your database was built from an OLDER copy of this repo, before
--  the fix below landed in schema/01_schema.sql and triggers/06_triggers.sql.
--  If you built (or rebuilt) the database from the CURRENT copy of
--  99_COMPLETE_HOSPITAL_DB.sql, your schema already has this change and
--  running this file is a harmless no-op — every statement below checks
--  first and skips if there is nothing to do.
--
--  It does NOT touch any data, indexes, functions, views or procedures.
--  It does not drop or rebuild anything except the one trigger it corrects.
--
--  RUN IT WITH:
--      mysql -u root -p hospital_management < database/changes.sql
--  or paste it into MySQL Workbench against the hospital_management schema.
-- ============================================================================
--
--  THE BUG THIS FIXES
--  The users table originally had only last_login. trg_users_au_session
--  (Member 5's session-tracking trigger) was written to also stamp a LOGOUT
--  audit row off a last_logout column that the table never had — so creating
--  that trigger failed outright with:
--      ERROR 1054 (42S22): Unknown column 'last_logout' in 'OLD'
--  and the trigger silently did not exist (14 of 15 triggers, not 15).
--  The backend's /auth/logout endpoint depends on this column and this
--  trigger to record a LOGOUT event in audit_logs.
-- ============================================================================

USE hospital_management;

-- ----------------------------------------------------------------------------
-- 1. ADD users.last_logout IF IT IS MISSING
--    Written as guarded dynamic SQL rather than a plain ALTER TABLE so this
--    file is safe to run on MySQL 8.0.16+ (the version this project targets) -
--    "ALTER TABLE ... ADD COLUMN IF NOT EXISTS" is only available from 8.0.29.
-- ----------------------------------------------------------------------------
SET @column_exists = (
    SELECT COUNT(*) FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = 'hospital_management'
      AND TABLE_NAME   = 'users'
      AND COLUMN_NAME  = 'last_logout'
);

SET @add_column_sql = IF(@column_exists = 0,
    'ALTER TABLE users ADD COLUMN last_logout DATETIME NULL AFTER last_login',
    'SELECT ''users.last_logout already exists - skipped'' AS status'
);

PREPARE stmt FROM @add_column_sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- ----------------------------------------------------------------------------
-- 2. (RE)CREATE trg_users_au_session WITH THE LOGOUT BRANCH
--    DROP + CREATE is naturally idempotent - safe whether the trigger never
--    existed, exists in the old LOGIN-only form, or already matches this.
-- ----------------------------------------------------------------------------
DROP TRIGGER IF EXISTS trg_users_au_session;

DELIMITER $$

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

DELIMITER ;

-- ============================================================================
-- VERIFY
-- ============================================================================
SELECT 'users.last_logout column' AS check_item,
       IF(COUNT(*) = 1, 'PASS', 'FAIL') AS result
FROM information_schema.COLUMNS
WHERE TABLE_SCHEMA = 'hospital_management' AND TABLE_NAME = 'users'
  AND COLUMN_NAME = 'last_logout'
UNION ALL
SELECT 'trg_users_au_session trigger',
       IF(COUNT(*) = 1, 'PASS', 'FAIL')
FROM information_schema.TRIGGERS
WHERE TRIGGER_SCHEMA = 'hospital_management' AND TRIGGER_NAME = 'trg_users_au_session'
UNION ALL
SELECT 'total triggers (expect 15)',
       IF(COUNT(*) = 15, 'PASS', 'FAIL')
FROM information_schema.TRIGGERS
WHERE TRIGGER_SCHEMA = 'hospital_management';

-- Live proof: this UPDATE should insert exactly one LOGOUT row.
SET @app_user_id = 1;
SELECT COUNT(*) INTO @logout_rows_before FROM audit_logs WHERE action = 'LOGOUT';
UPDATE users SET last_logout = NOW() WHERE user_id = 1;
SELECT COUNT(*) AS logout_rows_after,
       @logout_rows_before AS logout_rows_before,
       IF(COUNT(*) = @logout_rows_before + 1, 'PASS', 'FAIL') AS result
FROM audit_logs WHERE action = 'LOGOUT';

-- END OF changes.sql
