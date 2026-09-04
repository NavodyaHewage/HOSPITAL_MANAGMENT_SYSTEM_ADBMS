/** Mirrors com.hospital.hms.module.auth.dto.request.LoginRequest. */
export interface LoginRequest {
  username: string;
  password: string;
}

/** Mirrors com.hospital.hms.module.auth.dto.request.RefreshRequest. */
export interface RefreshRequest {
  refreshToken: string;
}

/**
 * Mirrors com.hospital.hms.module.auth.dto.response.CurrentUserResponse.
 * `roles` and `permissions` are the names resolved through
 * user_roles -> role_permissions -> permissions for this user.
 */
export interface CurrentUser {
  userId: number;
  username: string;
  fullName: string;
  email: string | null;
  phone: string | null;
  isActive: boolean;
  lastLogin: string | null;
  roles: string[];
  permissions: string[];
}

/** Mirrors com.hospital.hms.module.auth.dto.response.LoginResponse. */
export interface LoginResponse {
  accessToken: string;
  refreshToken: string;
  tokenType: string;
  expiresInSeconds: number;
  user: CurrentUser;
  permissions: string[];
}
