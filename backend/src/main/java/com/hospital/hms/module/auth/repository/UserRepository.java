package com.hospital.hms.module.auth.repository;

import com.hospital.hms.module.auth.entity.User;
import java.util.List;
import java.util.Optional;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;
import org.springframework.transaction.annotation.Transactional;

@Repository
public interface UserRepository extends JpaRepository<User, Integer> {

    Optional<User> findByUsername(String username);

    Optional<User> findByUsernameAndIsActiveTrue(String username);

    boolean existsByUsername(String username);

    Page<User> findAllByIsActiveTrue(Pageable pageable);

    /**
     * Resolves the effective permission names for a user, exactly the way
     * fn_check_user_permission does: an inactive user resolves to nothing.
     * These names become the JWT authorities.
     */
    @Query("""
            SELECT DISTINCT p.permissionName
            FROM User u
            JOIN u.roles r
            JOIN r.permissions p
            WHERE u.userId = :userId AND u.isActive = true
            """)
    List<String> findPermissionNames(@Param("userId") Integer userId);

    @Query("""
            SELECT DISTINCT r.roleName
            FROM User u JOIN u.roles r
            WHERE u.userId = :userId
            """)
    List<String> findRoleNames(@Param("userId") Integer userId);

    /**
     * Stamped on login. Deliberately a bulk UPDATE rather than a dirty-checked
     * save: it must touch last_login and nothing else, because
     * trg_users_au_session keys the LOGIN audit row off that column changing.
     *
     * <p>{@code @Transactional} lives here, not on AuthServiceImpl.login(),
     * because that method also has to call sp_handle_failed_login on a wrong
     * password - a stored procedure that runs its own START TRANSACTION /
     * COMMIT. Wrapping the whole method in a Spring transaction would nest
     * that around the procedure's self-commit, exactly the conflict
     * StoredProcedureExecutor's javadoc warns about. Scoping the transaction
     * to just this write (Spring Data supports {@code @Transactional} directly
     * on a repository method) keeps the two writes independent of whichever
     * branch of login() runs.
     */
    @Modifying
    @Transactional
    @Query("UPDATE User u SET u.lastLogin = CURRENT_TIMESTAMP WHERE u.userId = :userId")
    void stampLogin(@Param("userId") Integer userId);

    /** Stamped on logout - fires the LOGOUT branch of trg_users_au_session. */
    @Modifying
    @Transactional
    @Query("UPDATE User u SET u.lastLogout = CURRENT_TIMESTAMP WHERE u.userId = :userId")
    void stampLogout(@Param("userId") Integer userId);

    /**
     * Clears a stale counter after a successful login. Without this, failed
     * attempts from unrelated occasions weeks apart would keep accumulating
     * toward the same lockout threshold instead of each bad password being
     * judged against a fresh count - sp_handle_failed_login only ever
     * increments, it never resets on its own.
     */
    @Modifying
    @Transactional
    @Query("UPDATE User u SET u.failedAttempts = 0 WHERE u.userId = :userId AND u.failedAttempts <> 0")
    void resetFailedAttempts(@Param("userId") Integer userId);
}
