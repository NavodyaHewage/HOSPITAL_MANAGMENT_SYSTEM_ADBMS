package com.hospital.hms.module.auth.service.impl;

import com.hospital.hms.common.exception.UnauthorizedException;
import com.hospital.hms.module.auth.dto.request.LoginRequest;
import com.hospital.hms.module.auth.dto.request.RefreshRequest;
import com.hospital.hms.module.auth.dto.response.CurrentUserResponse;
import com.hospital.hms.module.auth.dto.response.LoginResponse;
import com.hospital.hms.module.auth.entity.User;
import com.hospital.hms.module.auth.repository.UserRepository;
import com.hospital.hms.module.auth.service.AuthService;
import com.hospital.hms.security.jwt.JwtProperties;
import com.hospital.hms.security.jwt.JwtService;
import java.util.List;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class AuthServiceImpl implements AuthService {

    private final UserRepository userRepository;
    private final PasswordEncoder passwordEncoder;
    private final JwtService jwtService;
    private final JwtProperties jwtProperties;

    public AuthServiceImpl(UserRepository userRepository,
                           PasswordEncoder passwordEncoder,
                           JwtService jwtService,
                           JwtProperties jwtProperties) {
        this.userRepository = userRepository;
        this.passwordEncoder = passwordEncoder;
        this.jwtService = jwtService;
        this.jwtProperties = jwtProperties;
    }

    @Override
    @Transactional
    public LoginResponse login(LoginRequest request) {
        // Deliberately one generic message for "no such user", "wrong password"
        // and "deactivated": distinguishing them tells an attacker which
        // usernames are real.
        User user = userRepository.findByUsername(request.username())
                .orElseThrow(() -> new UnauthorizedException("Invalid username or password"));

        if (!passwordEncoder.matches(request.password(), user.getPasswordHash())) {
            throw new UnauthorizedException("Invalid username or password");
        }
        if (Boolean.FALSE.equals(user.getIsActive())) {
            throw new UnauthorizedException("Invalid username or password");
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
