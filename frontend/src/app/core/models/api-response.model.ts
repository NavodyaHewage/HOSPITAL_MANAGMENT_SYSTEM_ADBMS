/**
 * Mirrors com.hospital.hms.common.dto.ApiResponse<T> - every endpoint in the
 * backend returns exactly this envelope, success or failure, so this is the
 * one response shape the whole app needs to know about.
 */
export interface ApiResponse<T> {
  success: boolean;
  message: string;
  data: T | null;
  timestamp: string;
}
