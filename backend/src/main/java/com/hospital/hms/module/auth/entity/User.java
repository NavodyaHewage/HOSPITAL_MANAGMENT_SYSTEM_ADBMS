package com.hospital.hms.module.auth.entity;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.FetchType;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.JoinTable;
import jakarta.persistence.ManyToMany;
import jakarta.persistence.Table;
import java.time.LocalDateTime;
import java.util.HashSet;
import java.util.Set;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

@Entity
@Table(name = "users")
@Getter
@Setter
@NoArgsConstructor
public class User {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "user_id")
    private Integer userId;

    @Column(name = "username", nullable = false, length = 50)
    private String username;

    @Column(name = "password_hash", nullable = false, length = 255)
    private String passwordHash;

    @Column(name = "email", length = 100)
    private String email;

    @Column(name = "full_name", nullable = false, length = 100)
    private String fullName;

    @Column(name = "phone", length = 20)
    private String phone;

    @Column(name = "is_active", nullable = false)
    private Boolean isActive;

    /** Writing this fires trg_users_au_session, which logs a LOGIN audit row. */
    @Column(name = "last_login")
    private LocalDateTime lastLogin;

    /** Writing this fires trg_users_au_session, which logs a LOGOUT audit row. */
    @Column(name = "last_logout")
    private LocalDateTime lastLogout;

    /**
     * Owned by sp_handle_failed_login (increments on a wrong password) and
     * sp_unlock_user_account (resets to 0) - see
     * database/member5_account_lockout.sql. AuthServiceImpl also clears this
     * directly on a successful login so a stale count from weeks of unrelated
     * typos doesn't compound toward the same lockout threshold.
     */
    @Column(name = "failed_attempts", nullable = false)
    private Integer failedAttempts;

    /**
     * True once failed_attempts reaches the lockout threshold set in
     * sp_handle_failed_login (5). AuthServiceImpl.login()/refresh() both
     * refuse a locked account regardless of password. Writing this flips
     * trg_users_account_locked_audit, which logs a LOCK/UNLOCK audit row.
     */
    @Column(name = "is_locked", nullable = false)
    private Boolean isLocked;

    @Column(name = "created_at", insertable = false, updatable = false)
    private LocalDateTime createdAt;

    @Column(name = "updated_at", insertable = false, updatable = false)
    private LocalDateTime updatedAt;

    @ManyToMany(fetch = FetchType.LAZY)
    @JoinTable(name = "user_roles",
            joinColumns = @JoinColumn(name = "user_id"),
            inverseJoinColumns = @JoinColumn(name = "role_id"))
    private Set<Role> roles = new HashSet<>();
}
