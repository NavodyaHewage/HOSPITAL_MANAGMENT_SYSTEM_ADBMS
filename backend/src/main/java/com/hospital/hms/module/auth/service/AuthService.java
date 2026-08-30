package com.hospital.hms.module.auth.service;

import com.hospital.hms.module.auth.dto.request.LoginRequest;
import com.hospital.hms.module.auth.dto.request.RefreshRequest;
import com.hospital.hms.module.auth.dto.response.CurrentUserResponse;
import com.hospital.hms.module.auth.dto.response.LoginResponse;

public interface AuthService {

    LoginResponse login(LoginRequest request);

    LoginResponse refresh(RefreshRequest request);

    void logout(String username);

    CurrentUserResponse currentUser(String username);
}
