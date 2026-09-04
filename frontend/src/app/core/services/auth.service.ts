import { Injectable, computed, inject, signal } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Router } from '@angular/router';
import { Observable, tap } from 'rxjs';
import { environment } from '../../../environments/environment';
import { ApiResponse } from '../models/api-response.model';
import { CurrentUser, LoginRequest, LoginResponse } from '../models/auth.model';
import { TokenStorageService } from './token-storage.service';

/**
 * Owns the session: login, logout, and the signals every guard, interceptor
 * and component reads to know who is signed in and what they may do.
 *
 * The permission and role lists come straight from the backend's response -
 * they are never computed or guessed client-side, because the backend is the
 * only place that actually knows what user_roles -> role_permissions
 * resolves to for this user.
 */
@Injectable({ providedIn: 'root' })
export class AuthService {
  private readonly http = inject(HttpClient);
  private readonly router = inject(Router);
  private readonly storage = inject(TokenStorageService);
  private readonly baseUrl = `${environment.apiUrl}/auth`;

  /**
   * Hydrated synchronously from storage, not fetched, so a page refresh does
   * not flash a "signed out" state before an async call resolves - the
   * backend is still the source of truth for whether the token is actually
   * still valid, which the auth interceptor enforces on the next request.
   */
  private readonly userSignal = signal<CurrentUser | null>(this.storage.getStoredUser());

  readonly currentUser = this.userSignal.asReadonly();
  readonly isAuthenticated = computed(() => this.userSignal() !== null);
  readonly permissions = computed(() => this.userSignal()?.permissions ?? []);
  readonly roles = computed(() => this.userSignal()?.roles ?? []);

  login(request: LoginRequest): Observable<ApiResponse<LoginResponse>> {
    return this.http
      .post<ApiResponse<LoginResponse>>(`${this.baseUrl}/login`, request)
      .pipe(tap((response) => this.applySession(response.data)));
  }

  /**
   * User-initiated sign-out. Best-effort: the POST stamps last_logout server
   * side, which fires trg_users_au_session and records a LOGOUT row in
   * audit_logs - but the local session is cleared and the user is sent to
   * /login regardless of whether that request succeeds, so a dead backend
   * can never trap someone in a signed-in-looking screen they can't use.
   */
  logout(): void {
    this.http.post(`${this.baseUrl}/logout`, {}).subscribe({
      complete: () => this.finishLogout(),
      error: () => this.finishLogout(),
    });
  }

  getAccessToken(): string | null {
    return this.storage.getAccessToken();
  }

  hasPermission(permission: string): boolean {
    return this.permissions().includes(permission);
  }

  hasAnyPermission(...permissions: string[]): boolean {
    return permissions.some((permission) => this.hasPermission(permission));
  }

  hasRole(role: string): boolean {
    return this.roles().includes(role);
  }

  /**
   * Internal cleanup only - no backend call, no navigation decision baked
   * in. Used by the auth interceptor when a request comes back 401: the
   * token is already invalid, so calling /auth/logout would just 401 again.
   */
  clearSession(): void {
    this.storage.clear();
    this.userSignal.set(null);
  }

  private finishLogout(): void {
    this.clearSession();
    this.router.navigateByUrl('/login');
  }

  private applySession(data: LoginResponse | null): void {
    if (!data) {
      return;
    }
    this.storage.setSession(data.accessToken, data.refreshToken, data.user);
    this.userSignal.set(data.user);
  }
}
