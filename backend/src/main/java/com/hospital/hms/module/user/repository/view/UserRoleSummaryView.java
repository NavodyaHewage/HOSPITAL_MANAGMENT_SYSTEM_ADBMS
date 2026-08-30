package com.hospital.hms.module.user.repository.view;

/** Projection over vw_user_role_summary. */
public interface UserRoleSummaryView {

    Integer getUserId();

    String getUsername();

    String getFullName();

    Boolean getIsActive();

    Long getRoleCount();

    /** Comma-separated, built by GROUP_CONCAT inside the view. */
    String getRoles();
}
