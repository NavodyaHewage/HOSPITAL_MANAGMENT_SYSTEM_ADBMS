import { Injectable, PLATFORM_ID, inject } from '@angular/core';
import { isPlatformBrowser } from '@angular/common';
import { CurrentUser } from '../models/auth.model';

const ACCESS_TOKEN_KEY = 'hms.accessToken';
const REFRESH_TOKEN_KEY = 'hms.refreshToken';
const USER_KEY = 'hms.currentUser';

/**
 * Wraps localStorage behind a platform check.
 *
 * This app renders through Angular SSR (see app.routes.server.ts): during a
 * server render there is no `window` or `localStorage`, so touching it
 * directly would throw and take the whole render down. Every read here
 * returns null on the server and every write is a no-op; AuthService hydrates
 * its signals from this on construction, which runs again once the app
 * bootstraps in the browser.
 */
@Injectable({ providedIn: 'root' })
export class TokenStorageService {
  private readonly isBrowser = isPlatformBrowser(inject(PLATFORM_ID));

  getAccessToken(): string | null {
    return this.read(ACCESS_TOKEN_KEY);
  }

  getRefreshToken(): string | null {
    return this.read(REFRESH_TOKEN_KEY);
  }

  getStoredUser(): CurrentUser | null {
    const raw = this.read(USER_KEY);
    if (!raw) {
      return null;
    }
    try {
      return JSON.parse(raw) as CurrentUser;
    } catch {
      return null;
    }
  }

  setSession(accessToken: string, refreshToken: string, user: CurrentUser): void {
    this.write(ACCESS_TOKEN_KEY, accessToken);
    this.write(REFRESH_TOKEN_KEY, refreshToken);
    this.write(USER_KEY, JSON.stringify(user));
  }

  clear(): void {
    if (!this.isBrowser) {
      return;
    }
    localStorage.removeItem(ACCESS_TOKEN_KEY);
    localStorage.removeItem(REFRESH_TOKEN_KEY);
    localStorage.removeItem(USER_KEY);
  }

  private read(key: string): string | null {
    return this.isBrowser ? localStorage.getItem(key) : null;
  }

  private write(key: string, value: string): void {
    if (this.isBrowser) {
      localStorage.setItem(key, value);
    }
  }
}
