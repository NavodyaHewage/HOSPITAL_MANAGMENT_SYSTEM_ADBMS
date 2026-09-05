-- ============================================================================
--  member5_account_lockout.sql
--  MEMBER 5 — Account Lockout Policy & Admin Unlock Management
-- ============================================================================
--  Adds brute-force login protection on top of the existing users/audit_logs
--  schema:
--    1. users.failed_attempts / users.is_locked
--    2. sp_handle_failed_login       — call this from the login endpoint on
--                                      every WRONG password. Locks the
--                                      account once failed_attempts reaches
--                                      v_max_attempts (5, see below).
--    3. sp_unlock_user_account       — admin-only reset, gated on the
--                                      existing USER_MANAGE permission via
--                                      fn_check_user_permission (03_functions.sql).
--    4. trg_users_account_locked_audit — writes a LOCK/UNLOCK row to
--                                      audit_logs whenever is_locked flips,
--                                      alongside the existing
--                                      trg_users_au_session trigger.
--    5. vw_locked_users              — currently-locked accounts + the most
--                                      recent LOCK event for each, read back
--                                      from audit_logs (no extra column
--                                      needed for "when").
--
--  Written the same way as changes.sql: every step is idempotent, so this
--  file is safe to (re)run against a database that already has some or all
--  of it. It does not touch any other table, procedure, trigger or view.
--
--  RUN IT WITH:
--      mysql -u root -p hospital_management < database/member5_account_lockout.sql
--  or paste it into MySQL Workbench against the hospital_management schema.
--
--  Requires MySQL 8.0.16+ (same baseline as the rest of this project).
-- ============================================================================

USE hospital_management;

-- ----------------------------------------------------------------------------
-- 1. users.failed_attempts / users.is_locked
--    Guarded dynamic SQL (not a plain ALTER TABLE) for the same reason as
--    changes.sql: "ADD COLUMN IF NOT EXISTS" needs MySQL 8.0.29+, and this
--    project targets 8.0.16+.
-- ----------------------------------------------------------------------------
SET @column_exists = (
    SELECT COUNT(*) FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = 'hospital_management'
      AND TABLE_NAME   = 'users'
      AND COLUMN_NAME  = 'failed_attempts'
);

SET @add_column_sql = IF(@column_exists = 0,
    'ALTER TABLE users ADD COLUMN failed_attempts INT NOT NULL DEFAULT 0 AFTER last_logout',
    'SELECT ''users.failed_attempts already exists - skipped'' AS status'
);

PREPARE stmt FROM @add_column_sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @column_exists = (
    SELECT COUNT(*) FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = 'hospital_management'
      AND TABLE_NAME   = 'users'
      AND COLUMN_NAME  = 'is_locked'
);

SET @add_column_sql = IF(@column_exists = 0,
    'ALTER TABLE users ADD COLUMN is_locked BOOLEAN NOT NULL DEFAULT FALSE AFTER failed_attempts',
    'SELECT ''users.is_locked already exists - skipped'' AS status'
);

PREPARE stmt FROM @add_column_sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- ----------------------------------------------------------------------------
-- 2. audit_logs.action — add 'LOCK' / 'UNLOCK' so the lockout trigger can
--    record a distinct event instead of overloading 'UPDATE', the same way
--    the existing session trigger already has its own 'LOGIN'/'LOGOUT'.
--    Guarded on the quoted literal so 'LOCK' doesn't false-match 'UNLOCK'.
-- ----------------------------------------------------------------------------
SET @enum_has_lock = (
    SELECT COUNT(*) FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = 'hospital_management'
      AND TABLE_NAME   = 'audit_logs'
      AND COLUMN_NAME  = 'action'
      AND COLUMN_TYPE  LIKE '%''LOCK''%'
);

SET @alter_enum_sql = IF(@enum_has_lock = 0,
    'ALTER TABLE audit_logs MODIFY COLUMN action ENUM(''INSERT'',''UPDATE'',''DELETE'',''LOGIN'',''LOGOUT'',''LOCK'',''UNLOCK'') NOT NULL',
    'SELECT ''audit_logs.action already has LOCK/UNLOCK - skipped'' AS status'
);

PREPARE stmt FROM @alter_enum_sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- ----------------------------------------------------------------------------
-- 3. PROCEDURES + TRIGGER
-- ----------------------------------------------------------------------------
DELIMITER $$

-- Call on every failed password check. Increments failed_attempts and locks
-- the account once the threshold is hit. A no-op on an already-locked
-- account, so repeated attempts against a locked account don't keep
-- rewriting the row or re-firing the LOCK audit event.
DROP PROCEDURE IF EXISTS sp_handle_failed_login$$
CREATE PROCEDURE sp_handle_failed_login(IN p_username VARCHAR(255))
MODIFIES SQL DATA
BEGIN
    DECLARE v_user_id         INT DEFAULT NULL;
    DECLARE v_failed_attempts INT DEFAULT 0;
    DECLARE v_is_locked       BOOLEAN DEFAULT FALSE;
    DECLARE v_max_attempts    INT DEFAULT 5;   -- lockout threshold

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    -- Pessimistic lock on the user row: two concurrent failed logins for the
    -- same username must not both read attempts=4 and both write 5.
    SELECT user_id, failed_attempts, is_locked
      INTO v_user_id, v_failed_attempts, v_is_locked
      FROM users
     WHERE username = p_username
     FOR UPDATE;

    IF v_user_id IS NULL THEN
        ROLLBACK;
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'User not found';
    END IF;

    IF NOT v_is_locked THEN
        SET v_failed_attempts = v_failed_attempts + 1;

        -- Lets the audit trigger record WHO/WHAT triggered the change.
        SET @app_user_id = v_user_id;

        UPDATE users
           SET failed_attempts = v_failed_attempts,
               is_locked       = (v_failed_attempts >= v_max_attempts)
         WHERE user_id = v_user_id;
    END IF;

    COMMIT;
END$$

-- Admin-only reset. Gated on the USER_MANAGE permission that already exists
-- in the permissions table (see functions/03_functions.sql, seed/02_seed_data.sql).
DROP PROCEDURE IF EXISTS sp_unlock_user_account$$
CREATE PROCEDURE sp_unlock_user_account(
    IN p_user_id  BIGINT,
    IN p_admin_id BIGINT
)
MODIFIES SQL DATA
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    IF NOT fn_check_user_permission(p_admin_id, 'USER_MANAGE') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Admin does not have USER_MANAGE permission';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM users WHERE user_id = p_user_id) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'User does not exist';
    END IF;

    -- Lets the audit trigger record WHO did it.
    SET @app_user_id = p_admin_id;

    START TRANSACTION;

    UPDATE users
       SET is_locked       = FALSE,
           failed_attempts = 0
     WHERE user_id = p_user_id;

    COMMIT;
END$$

-- Fires alongside the existing trg_users_au_session (login/logout/is_active)
-- whenever is_locked flips, logging a LOCK or UNLOCK row.
DROP TRIGGER IF EXISTS trg_users_account_locked_audit$$
CREATE TRIGGER trg_users_account_locked_audit
AFTER UPDATE ON users
FOR EACH ROW
BEGIN
    IF NOT (OLD.is_locked <=> NEW.is_locked) THEN
        INSERT INTO audit_logs (user_id, entity_name, entity_id, action, old_value, new_value)
        VALUES (@app_user_id, 'users', NEW.user_id,
                IF(NEW.is_locked, 'LOCK', 'UNLOCK'),
                CONCAT('failed_attempts=', OLD.failed_attempts),
                CONCAT('failed_attempts=', NEW.failed_attempts));
    END IF;
END$$

DELIMITER ;

-- ----------------------------------------------------------------------------
-- 4. VIEW — currently locked users + their most recent LOCK event
-- ----------------------------------------------------------------------------
CREATE OR REPLACE VIEW vw_locked_users AS
SELECT u.user_id,
       u.username,
       u.full_name,
       u.email,
       u.failed_attempts,
       last_lock.locked_at
FROM users u
LEFT JOIN (
    SELECT al.entity_id AS user_id,
           al.created_at AS locked_at,
           ROW_NUMBER() OVER (PARTITION BY al.entity_id ORDER BY al.created_at DESC) AS rn
    FROM audit_logs al
    WHERE al.entity_name = 'users' AND al.action = 'LOCK'
) last_lock ON last_lock.user_id = u.user_id AND last_lock.rn = 1
WHERE u.is_locked = TRUE;

-- ============================================================================
-- VERIFY
-- ============================================================================
SELECT 'users.failed_attempts column' AS check_item,
       IF(COUNT(*) = 1, 'PASS', 'FAIL') AS result
FROM information_schema.COLUMNS
WHERE TABLE_SCHEMA = 'hospital_management' AND TABLE_NAME = 'users'
  AND COLUMN_NAME = 'failed_attempts'
UNION ALL
SELECT 'users.is_locked column',
       IF(COUNT(*) = 1, 'PASS', 'FAIL')
FROM information_schema.COLUMNS
WHERE TABLE_SCHEMA = 'hospital_management' AND TABLE_NAME = 'users'
  AND COLUMN_NAME = 'is_locked'
UNION ALL
SELECT 'audit_logs.action has LOCK/UNLOCK',
       IF(COUNT(*) = 1, 'PASS', 'FAIL')
FROM information_schema.COLUMNS
WHERE TABLE_SCHEMA = 'hospital_management' AND TABLE_NAME = 'audit_logs'
  AND COLUMN_NAME = 'action' AND COLUMN_TYPE LIKE '%''LOCK''%'
UNION ALL
SELECT 'sp_handle_failed_login procedure',
       IF(COUNT(*) = 1, 'PASS', 'FAIL')
FROM information_schema.ROUTINES
WHERE ROUTINE_SCHEMA = 'hospital_management' AND ROUTINE_NAME = 'sp_handle_failed_login'
UNION ALL
SELECT 'sp_unlock_user_account procedure',
       IF(COUNT(*) = 1, 'PASS', 'FAIL')
FROM information_schema.ROUTINES
WHERE ROUTINE_SCHEMA = 'hospital_management' AND ROUTINE_NAME = 'sp_unlock_user_account'
UNION ALL
SELECT 'trg_users_account_locked_audit trigger',
       IF(COUNT(*) = 1, 'PASS', 'FAIL')
FROM information_schema.TRIGGERS
WHERE TRIGGER_SCHEMA = 'hospital_management' AND TRIGGER_NAME = 'trg_users_account_locked_audit'
UNION ALL
SELECT 'vw_locked_users view',
       IF(COUNT(*) = 1, 'PASS', 'FAIL')
FROM information_schema.VIEWS
WHERE TABLE_SCHEMA = 'hospital_management' AND TABLE_NAME = 'vw_locked_users';

-- Live proof: 5 failed logins against the same username lock the account and
-- produce exactly one LOCK row; sp_unlock_user_account reverses it and
-- produces exactly one UNLOCK row.
-- @test_user_id is any non-admin seeded user (seed/02_seed_data.sql /
-- 99_COMPLETE_HOSPITAL_DB.sql assign role_id = 1 + (n % 7), so role_id 1 = ADMIN);
-- @admin_id is a seeded user who actually holds the ADMIN role, since
-- sp_unlock_user_account is gated on the USER_MANAGE permission.
SET @test_user_id = (
    SELECT ur.user_id FROM user_roles ur WHERE ur.role_id <> 1 LIMIT 1
);
SET @test_username = (SELECT username FROM users WHERE user_id = @test_user_id);
SET @admin_id = (
    SELECT ur.user_id FROM user_roles ur WHERE ur.role_id = 1 LIMIT 1
);

CALL sp_handle_failed_login(@test_username);
CALL sp_handle_failed_login(@test_username);
CALL sp_handle_failed_login(@test_username);
CALL sp_handle_failed_login(@test_username);
CALL sp_handle_failed_login(@test_username);

SELECT user_id, username, failed_attempts, is_locked
FROM users WHERE user_id = @test_user_id;

SELECT * FROM vw_locked_users WHERE user_id = @test_user_id;

CALL sp_unlock_user_account(@test_user_id, @admin_id);

SELECT user_id, username, failed_attempts, is_locked
FROM users WHERE user_id = @test_user_id;

SELECT entity_id, action, old_value, new_value, created_at
FROM audit_logs
WHERE entity_name = 'users' AND entity_id = @test_user_id AND action IN ('LOCK','UNLOCK')
ORDER BY created_at DESC
LIMIT 5;

-- END OF member5_account_lockout.sql
