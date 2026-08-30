package com.hospital.hms.module.user.repository.view;

/** Projection over vw_permission_matrix. */
public interface PermissionMatrixView {

    Integer getRoleId();

    String getRoleName();

    Integer getPermissionId();

    String getPermissionName();

    String getModule();
}
