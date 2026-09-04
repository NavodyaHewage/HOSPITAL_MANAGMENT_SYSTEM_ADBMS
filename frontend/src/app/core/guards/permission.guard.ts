import { inject } from '@angular/core';
import { CanActivateFn, Router } from '@angular/router';
import { AuthService } from '../services/auth.service';

/**
 * Guards a route on a permission rather than just on being signed in.
 *
 * Two different refusals, deliberately: someone who is not signed in is sent
 * to /login with a returnUrl so they land where they meant to, while someone
 * who is signed in but lacks the permission is sent to /dashboard - logging
 * them out and back in would not help them.
 *
 * This is convenience, not security. The backend checks the same permission
 * with @PreAuthorize on every request; this only avoids showing a screen
 * whose every action would come back 403.
 *
 * @example
 * canActivate: [permissionGuard(Permissions.USER_MANAGE)]
 */
export const permissionGuard = (...permissions: string[]): CanActivateFn => {
  return (_route, state) => {
    const authService = inject(AuthService);
    const router = inject(Router);

    if (!authService.isAuthenticated()) {
      return router.createUrlTree(['/login'], { queryParams: { returnUrl: state.url } });
    }

    if (authService.hasAnyPermission(...permissions)) {
      return true;
    }

    return router.createUrlTree(['/dashboard']);
  };
};
