package com.hospital.hms.module.user.repository.view;

import com.hospital.hms.module.auth.entity.User;
import java.util.List;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.Repository;
import org.springframework.data.repository.query.Param;

public interface UserViewRepository extends Repository<User, Integer> {

    @Query(value = """
            SELECT user_id, username, full_name, is_active, role_count, roles
            FROM vw_user_role_summary
            WHERE (:activeOnly = false OR is_active = 1)
            ORDER BY username
            """, nativeQuery = true)
    List<UserRoleSummaryView> findUserRoleSummary(@Param("activeOnly") boolean activeOnly);

    @Query(value = """
            SELECT role_id, role_name, permission_id, permission_name, module
            FROM vw_permission_matrix
            ORDER BY role_name, module, permission_name
            """, nativeQuery = true)
    List<PermissionMatrixView> findPermissionMatrix();
}
