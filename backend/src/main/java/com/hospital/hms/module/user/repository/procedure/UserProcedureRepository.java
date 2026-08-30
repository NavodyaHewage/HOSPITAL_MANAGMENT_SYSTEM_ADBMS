package com.hospital.hms.module.user.repository.procedure;

import com.hospital.hms.common.jdbc.StoredProcedureExecutor;
import com.hospital.hms.module.user.dto.request.CreateUserRequest;
import java.util.HashMap;
import java.util.Map;
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

    private static final String SP_CREATE_USER = "sp_create_user_with_role";
    private static final String SP_ASSIGN_REVOKE = "sp_assign_revoke_role_permission";
    private static final String FN_CHECK_PERMISSION = "fn_check_user_permission";

    private final StoredProcedureExecutor executor;

    public UserProcedureRepository(StoredProcedureExecutor executor) {
        this.executor = executor;
    }

    /** The procedure hashes the password with SHA2(...,256) - see MysqlSha256PasswordEncoder. */
    public Integer createUserWithRole(CreateUserRequest request, String assignedBy) {
        Map<String, Object> params = new HashMap<>();
        params.put("p_user_id", null);
        params.put("p_username", request.username());
        params.put("p_password", request.password());
        params.put("p_email", request.email());
        params.put("p_full_name", request.fullName());
        params.put("p_phone", request.phone());
        params.put("p_role_name", request.roleName());
        params.put("p_assigned_by", assignedBy);

        Map<String, Object> out = executor.call(SP_CREATE_USER, params);
        Object id = out.get("p_user_id");
        return id == null ? null : ((Number) id).intValue();
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
