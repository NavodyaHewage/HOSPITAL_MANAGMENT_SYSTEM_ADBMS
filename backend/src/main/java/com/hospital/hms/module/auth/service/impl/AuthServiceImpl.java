package com.hospital.hms.module.auth.service.impl;

import com.hospital.hms.common.exception.UnauthorizedException;
import com.hospital.hms.module.auth.dto.request.LoginRequest;
import com.hospital.hms.module.auth.dto.request.RefreshRequest;
import com.hospital.hms.module.auth.dto.response.CurrentUserResponse;
import com.hospital.hms.module.auth.dto.response.LoginResponse;
import com.hospital.hms.module.auth.entity.User;
import com.hospital.hms.module.auth.repository.UserRepository;
import com.hospital.hms.module.auth.repository.procedure.AuthProcedureRepository;
import com.hospital.hms.module.auth.service.AuthService;
import com.hospital.hms.security.jwt.JwtProperties;
import com.hospital.hms.security.jwt.JwtService;
import java.util.List;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Account lockout is enforced here, not just at the database:
 * sp_handle_failed_login only ever increments a counter and flips a flag - it
 * is this service that turns "is_locked = true" into a refused login, on both
 * the initial sign-in and every refresh (a token minted before the lock must
 * not be quietly renewable forever).
 */
@Service
public class AuthServiceImpl implements AuthService {

    private static final String LOCKED_MESSAGE =
            "This account is locked due to too many failed sign-in attempts. Contact an administrator to unlock it.";

    private final UserRepository userRepository;
    private final AuthProcedureRepository authProcedureRepository;
    private final PasswordEncoder passwordEncoder;
    private final JwtService jwtService;
    private final JwtProperties jwtProperties;

    public AuthServiceImpl(UserRepository userRepository,
                           AuthProcedureRepository authProcedureRepository,
                           PasswordEncoder passwordEncoder,
                           JwtService jwtService,
                           JwtProperties jwtProperties) {
        this.userRepository = userRepository;
        this.authProcedureRepository = authProcedureRepository;
        this.passwordEncoder = passwordEncoder;
        this.jwtService = jwtService;
        this.jwtProperties = jwtProperties;
    }

    /**
     * No {@code @Transactional} here - a wrong password calls
     * sp_handle_failed_login, which runs its own self-committing transaction
     * and must not be nested inside one of Spring's (see
     * StoredProcedureExecutor). The two writes on the success path
     * (resetFailedAttempts, stampLogin) each carry their own
     * {@code @Transactional} directly on the UserRepository method instead.
     */
    @Override
    public LoginResponse login(LoginRequest request) {
        // Deliberately one generic message for "no such user" and "wrong
        // password": distinguishing them tells an attacker which usernames
        // are real. A lockout is different - the legitimate owner of the
        // account needs to know to stop guessing and contact an admin, so
        // that message is deliberately distinct rather than folded into the
        // generic one.
        User user = userRepository.findByUsername(request.username())
                .orElseThrow(() -> new UnauthorizedException("Invalid username or password"));

        if (Boolean.TRUE.equals(user.getIsLocked())) {
            throw new UnauthorizedException(LOCKED_MESSAGE);
        }

        if (!passwordEncoder.matches(request.password(), user.getPasswordHash())) {
            // Increments failed_attempts and locks the account once it hits
            // the threshold (5) - see sp_handle_failed_login. Re-read the row
            // afterward: this specific wrong password may be the one that
            // just crossed it, which changes what the caller needs to hear.
            authProcedureRepository.handleFailedLogin(user.getUsername());

            boolean nowLocked = userRepository.findById(user.getUserId())
                    .map(User::getIsLocked)
                    .map(Boolean.TRUE::equals)
                    .orElse(false);
            if (nowLocked) {
                throw new UnauthorizedException(
                        "Too many failed sign-in attempts. This account is now locked - contact an administrator to unlock it.");
            }
            throw new UnauthorizedException("Invalid username or password");
        }

        if (Boolean.FALSE.equals(user.getIsActive())) {
            throw new UnauthorizedException("Invalid username or password");
        }

        if (user.getFailedAttempts() != null && user.getFailedAttempts() > 0) {
            userRepository.resetFailedAttempts(user.getUserId());
        }

        // Fires trg_users_au_session -> writes the LOGIN row into audit_logs.
        userRepository.stampLogin(user.getUserId());

        return buildLoginResponse(user);
    }

    @Override
    @Transactional(readOnly = true)
    public LoginResponse refresh(RefreshRequest request) {
        if (!jwtService.isValid(request.refreshToken())) {
            throw new UnauthorizedException("Refresh token is invalid or has expired");
        }
        // The refresh token's subject is the user id (see JwtServiceImpl).
        Integer userId;
        try {
            userId = Integer.valueOf(jwtService.extractUsername(request.refreshToken()));
        } catch (NumberFormatException ex) {
            throw new UnauthorizedException("Refresh token is malformed");
        }

        User user = userRepository.findById(userId)
                .orElseThrow(() -> new UnauthorizedException("Account no longer exists"));
        if (Boolean.FALSE.equals(user.getIsActive())) {
            throw new UnauthorizedException("Account has been deactivated");
        }
        // A lock imposed mid-session must stop a still-valid refresh token
        // from quietly minting a new access token forever.
        if (Boolean.TRUE.equals(user.getIsLocked())) {
            throw new UnauthorizedException(LOCKED_MESSAGE);
        }
        // Permissions are re-read here, not carried over: a role revoked since
        // the original login must not survive into the refreshed token.
        return buildLoginResponse(user);
    }

    @Override
    @Transactional
    public void logout(String username) {
        userRepository.findByUsername(username)
                .ifPresent(user -> userRepository.stampLogout(user.getUserId()));
    }

    @Override
    @Transactional(readOnly = true)
    public CurrentUserResponse currentUser(String username) {
        User user = userRepository.findByUsername(username)
                .orElseThrow(() -> new UnauthorizedException("Session user no longer exists"));
        return toCurrentUser(user);
    }

    private LoginResponse buildLoginResponse(User user) {
        List<String> permissions = userRepository.findPermissionNames(user.getUserId());
        String access = jwtService.generateAccessToken(user.getUserId(), user.getUsername(), permissions);
        String refresh = jwtService.generateRefreshToken(user.getUserId());
        return new LoginResponse(
                access,
                refresh,
                "Bearer",
                jwtProperties.accessTokenExpiryMinutes() * 60,
                toCurrentUser(user),
                permissions);
    }

    private CurrentUserResponse toCurrentUser(User user) {
        return new CurrentUserResponse(
                user.getUserId(),
                user.getUsername(),
                user.getFullName(),
                user.getEmail(),
                user.getPhone(),
                user.getIsActive(),
                user.getLastLogin(),
                userRepository.findRoleNames(user.getUserId()),
                userRepository.findPermissionNames(user.getUserId()));
    }
}
