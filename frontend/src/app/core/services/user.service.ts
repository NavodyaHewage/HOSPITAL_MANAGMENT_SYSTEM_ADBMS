import { Injectable, inject } from '@angular/core';
import { HttpClient, HttpParams } from '@angular/common/http';
import { Observable } from 'rxjs';
import { environment } from '../../../environments/environment';
import { ApiResponse } from '../models/api-response.model';
import { PageResponse } from '../models/page-response.model';
import { CreateUserRequest, UserResponse } from '../models/user.model';

/**
 * System user administration. Every call here needs USER_MANAGE - the backend
 * enforces it at the controller, and permissionGuard/roleGuard keep the
 * screens behind the same authority so a user is never shown a form or table
 * whose actions would all come back 403.
 */
@Injectable({ providedIn: 'root' })
export class UserService {
  private readonly http = inject(HttpClient);
  private readonly baseUrl = `${environment.apiUrl}/users`;

  /**
   * Creates the account and assigns its role in one backend transaction
   * (sp_create_user_with_role). A duplicate username or email comes back as
   * 409 carrying the message the procedure itself raised.
   */
  createUser(request: CreateUserRequest): Observable<ApiResponse<UserResponse>> {
    return this.http.post<ApiResponse<UserResponse>>(this.baseUrl, request);
  }

  /**
   * includeInactive defaults to true here - the admin management table is the
   * one place a disabled account has to stay visible, or there is no way to
   * find it again to re-enable it.
   */
  listUsers(page: number, size: number, includeInactive = true): Observable<ApiResponse<PageResponse<UserResponse>>> {
    const params = new HttpParams()
      .set('page', page)
      .set('size', size)
      .set('includeInactive', includeInactive);
    return this.http.get<ApiResponse<PageResponse<UserResponse>>>(this.baseUrl, { params });
  }

  /**
   * Enables or disables an account. The backend deactivates rather than
   * deletes - audit_logs.user_id is ON DELETE SET NULL, so a hard delete
   * would anonymise the very history a hospital most needs to keep.
   */
  setActive(userId: number, active: boolean): Observable<ApiResponse<void>> {
    const params = new HttpParams().set('active', active);
    return this.http.patch<ApiResponse<void>>(`${this.baseUrl}/${userId}/active`, null, { params });
  }

  /**
   * Resets a locked account (sp_unlock_user_account): is_locked back to
   * false, failed_attempts back to 0.
   *
   * This one action's path is versioned (/api/v1/users/{id}/unlock), unlike
   * the rest of this service - it lives behind UserUnlockController on the
   * backend rather than UserController, so it is built from environment.apiUrl
   * directly instead of this.baseUrl.
   */
  unlockUser(userId: number): Observable<ApiResponse<void>> {
    return this.http.patch<ApiResponse<void>>(`${environment.apiUrl}/v1/users/${userId}/unlock`, null);
  }
}
