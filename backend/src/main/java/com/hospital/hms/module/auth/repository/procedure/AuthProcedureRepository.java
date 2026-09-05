package com.hospital.hms.module.auth.repository.procedure;

import com.hospital.hms.common.jdbc.StoredProcedureExecutor;
import java.util.Map;
import org.springframework.stereotype.Repository;

/**
 * Wraps sp_handle_failed_login (see database/member5_account_lockout.sql).
 *
 * <p>Call this on every wrong password, unconditionally. The procedure sets
 * {@code @app_user_id} to the affected user's own id before writing the LOCK
 * audit row - a failed login is the user's own action, not an admin's, so
 * unlike sp_create_user_with_role it needs no session-variable coordination
 * from Java. It also runs its own START TRANSACTION / COMMIT (never call it
 * from inside a Spring {@code @Transactional}) and is a no-op on an
 * already-locked account, so repeated wrong passwords against a locked
 * account don't keep rewriting the row or re-firing the LOCK audit event.
 */
@Repository
public class AuthProcedureRepository {

    private static final String SP_HANDLE_FAILED_LOGIN = "sp_handle_failed_login";

    private final StoredProcedureExecutor executor;

    public AuthProcedureRepository(StoredProcedureExecutor executor) {
        this.executor = executor;
    }

    public void handleFailedLogin(String username) {
        executor.call(SP_HANDLE_FAILED_LOGIN, Map.of("p_username", username));
    }
}
