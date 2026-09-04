package com.hospital.hms.module.user.repository.procedure;

import com.hospital.hms.common.jdbc.StoredProcedureExecutor;
import com.hospital.hms.module.user.dto.request.CreateUserRequest;
import java.sql.CallableStatement;
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.SQLException;
import java.sql.Types;
import java.util.HashMap;
import java.util.Map;
import org.springframework.dao.DataAccessException;
import org.springframework.jdbc.core.ConnectionCallback;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;

/**
 * Wraps sp_create_user_with_role and sp_assign_revoke_role_permission.
 *
 * <p>Creating a user and granting their role is one transaction: a user with no
 * role can sign in but do nothing, so a half-applied create is worse than none.
 * Grants and revokes go through the procedure too, because it writes the
 * audit_logs row inside the same transaction as the change - an audit entry
 * that can disagree with the data it audits is worse than no audit entry.
 */
@Repository
public class UserProcedureRepository {

    private static final String SP_ASSIGN_REVOKE = "sp_assign_revoke_role_permission";
    private static final String FN_CHECK_PERMISSION = "fn_check_user_permission";

    private static final String CALL_CREATE_USER =
            "{CALL sp_create_user_with_role(?, ?, ?, ?, ?, ?, ?, ?)}";

    private static final String SET_AUDIT_SESSION_USER = "SET @app_user_id = ?";

    private final StoredProcedureExecutor executor;
    private final JdbcTemplate jdbcTemplate;

    public UserProcedureRepository(StoredProcedureExecutor executor, JdbcTemplate jdbcTemplate) {
        this.executor = executor;
        this.jdbcTemplate = jdbcTemplate;
    }

    /**
     * The procedure hashes the password with SHA2(...,256) - see MysqlSha256PasswordEncoder.
     *
     * <p>This one call does not use SimpleJdbcCall, because two statements must
     * share one physical connection. trg_users_ai_audit stamps
     * audit_logs.user_id from the session variable {@code @app_user_id}, and a
     * variable set on a different pooled connection is invisible to the
     * procedure - the audit row then records that a user was created but not
     * who created it. ConnectionCallback pins both statements to one connection.
     *
     * @param actorUserId the operator creating the account; null only when
     *                    there is no authenticated principal
     */
    public Integer createUserWithRole(CreateUserRequest request, String assignedBy,
                                      Integer actorUserId) {
        try {
            return jdbcTemplate.execute((ConnectionCallback<Integer>) connection -> {
                setAuditSessionUser(connection, actorUserId);

                try (CallableStatement call = connection.prepareCall(CALL_CREATE_USER)) {
                    // INOUT p_user_id: NULL in means "insert a new user".
                    call.setNull(1, Types.INTEGER);
                    call.registerOutParameter(1, Types.INTEGER);

                    call.setString(2, request.username());
                    call.setString(3, request.password());
                    call.setString(4, request.email());
                    call.setString(5, request.fullName());
                    call.setString(6, request.phone());
                    call.setString(7, request.roleName());
                    call.setString(8, assignedBy);

                    call.execute();
                    return call.getInt(1);
                }
            });
        } catch (DataAccessException ex) {
            throw StoredProcedureExecutor.translate(ex);
        }
    }

    private void setAuditSessionUser(Connection connection, Integer actorUserId) throws SQLException {
        try (PreparedStatement statement = connection.prepareStatement(SET_AUDIT_SESSION_USER)) {
            if (actorUserId == null) {
                statement.setNull(1, Types.INTEGER);
            } else {
                statement.setInt(1, actorUserId);
            }
            statement.execute();
        }
    }

    /** action is ASSIGN or REVOKE; ASSIGN is idempotent via UNIQUE(role_id, permission_id). */
    public void assignOrRevoke(Integer roleId, Integer permissionId, String action,
                               Integer actorUserId) {
        Map<String, Object> params = new HashMap<>();
        params.put("p_role_id", roleId);
        params.put("p_permission_id", permissionId);
        params.put("p_action", action);
        params.put("p_actor_user_id", actorUserId);

        executor.call(SP_ASSIGN_REVOKE, params);
    }

    /** fn_check_user_permission - an inactive user never passes. */
    public boolean hasPermission(Integer userId, String permissionName) {
        Boolean has = executor.callFunction(FN_CHECK_PERMISSION, Boolean.class,
                userId, permissionName);
        return Boolean.TRUE.equals(has);
    }
}
