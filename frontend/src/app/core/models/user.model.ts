import { Role } from './roles';

/**
 * Mirrors com.hospital.hms.module.user.dto.request.CreateUserRequest.
 * Field names and limits must match it exactly - the backend validates the
 * same rules again and answers 400 with a field->message map if they drift.
 */
export interface CreateUserRequest {
  username: string;
  password: string;
  email: string | null;
  fullName: string;
  phone: string;
  roleName: Role;
}

/** Mirrors com.hospital.hms.module.user.dto.response.UserResponse. */
export interface UserResponse {
  userId: number;
  username: string;
  fullName: string;
  email: string | null;
  phone: string | null;
  isActive: boolean;
  lastLogin: string | null;
  lastLogout: string | null;
  createdAt: string | null;
  /** True once sp_handle_failed_login has locked this account. */
  isLocked: boolean;
  /** Consecutive wrong passwords since the last success or admin unlock. */
  failedAttempts: number;
  roles: string[];
  permissions: string[];
}
