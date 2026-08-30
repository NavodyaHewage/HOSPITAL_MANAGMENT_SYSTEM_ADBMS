package com.hospital.hms.module.user.dto.request;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;

public record RolePermissionRequest(
        @NotNull Integer roleId,
        @NotNull Integer permissionId,

        @NotBlank @Pattern(regexp = "ASSIGN|REVOKE", message = "must be ASSIGN or REVOKE")
        String action) {
}
