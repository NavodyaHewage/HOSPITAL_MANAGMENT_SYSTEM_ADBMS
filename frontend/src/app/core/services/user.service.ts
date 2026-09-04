import { Injectable, inject } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable } from 'rxjs';
import { environment } from '../../../environments/environment';
import { ApiResponse } from '../models/api-response.model';
import { CreateUserRequest, UserResponse } from '../models/user.model';

/**
 * System user administration. Every call here needs USER_MANAGE - the backend
 * enforces it at the controller, and permissionGuard keeps the screens behind
 * the same permission so a user is never shown a form they cannot submit.
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
}
