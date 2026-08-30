package com.hospital.hms.module.auth.controller;

import com.hospital.hms.common.dto.ApiResponse;
import com.hospital.hms.module.auth.dto.request.LoginRequest;
import com.hospital.hms.module.auth.dto.request.RefreshRequest;
import com.hospital.hms.module.auth.dto.response.CurrentUserResponse;
import com.hospital.hms.module.auth.dto.response.LoginResponse;
import com.hospital.hms.module.auth.service.AuthService;
import jakarta.validation.Valid;
import java.security.Principal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/auth")
public class AuthController {

    private final AuthService authService;

    public AuthController(AuthService authService) {
        this.authService = authService;
    }

    @PostMapping("/login")
    public ApiResponse<LoginResponse> login(@Valid @RequestBody LoginRequest request) {
        return ApiResponse.ok("Login successful", authService.login(request));
    }

    @PostMapping("/refresh")
    public ApiResponse<LoginResponse> refresh(@Valid @RequestBody RefreshRequest request) {
        return ApiResponse.ok("Token refreshed", authService.refresh(request));
    }

    @PostMapping("/logout")
    public ApiResponse<Void> logout(Principal principal) {
        if (principal != null) {
            authService.logout(principal.getName());
        }
        return ApiResponse.ok("Logged out", null);
    }

    @GetMapping("/me")
    public ApiResponse<CurrentUserResponse> me(Principal principal) {
        return ApiResponse.ok(authService.currentUser(principal.getName()));
    }
}
