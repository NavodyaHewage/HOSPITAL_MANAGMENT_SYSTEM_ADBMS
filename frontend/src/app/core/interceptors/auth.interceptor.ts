import { HttpErrorResponse, HttpInterceptorFn } from '@angular/common/http';
import { PLATFORM_ID, inject } from '@angular/core';
import { isPlatformBrowser } from '@angular/common';
import { Router } from '@angular/router';
import { catchError, throwError } from 'rxjs';
import { AuthService } from '../services/auth.service';

/**
 * Attaches the bearer token to every request except the two anonymous auth
 * endpoints (login and refresh never carry one, and the backend treats them
 * as public - see SecurityConfig.requestMatchers("/auth/login", "/auth/refresh")).
 *
 * On a 401 the token is missing, invalid or expired: the session is cleared
 * and the user is bounced to /login with a returnUrl. A 403 is deliberately
 * left alone - it means the session IS valid but the signed-in role lacks
 * the permission for that call, which is a page-level concern (show an
 * error, hide a button), not a reason to sign the user out.
 */
export const authInterceptor: HttpInterceptorFn = (req, next) => {
  const authService = inject(AuthService);
  const router = inject(Router);
  const isBrowser = isPlatformBrowser(inject(PLATFORM_ID));

  const isAnonymousAuthCall = req.url.endsWith('/auth/login') || req.url.endsWith('/auth/refresh');
  const token = authService.getAccessToken();

  const authorizedReq =
    !isAnonymousAuthCall && token
      ? req.clone({ setHeaders: { Authorization: `Bearer ${token}` } })
      : req;

  return next(authorizedReq).pipe(
    catchError((error: unknown) => {
      if (error instanceof HttpErrorResponse && error.status === 401 && !isAnonymousAuthCall) {
        authService.clearSession();
        if (isBrowser) {
          void router.navigate(['/login'], { queryParams: { returnUrl: router.url } });
        }
      }
      return throwError(() => error);
    }),
  );
};
