/**
 * Mirrors com.hospital.hms.common.dto.PageResponse<T> - the pagination
 * envelope wrapped inside ApiResponse<PageResponse<T>> on every list endpoint.
 */
export interface PageResponse<T> {
  content: T[];
  page: number;
  size: number;
  totalElements: number;
  totalPages: number;
}
