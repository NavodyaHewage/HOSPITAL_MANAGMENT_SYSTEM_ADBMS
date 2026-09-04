import { inject } from '@angular/core';
import { CanActivateFn, Router } from '@angular/router';
import { AuthService } from '../services/auth.service';

/**
 * Guards a route on role membership rather than on a single permission.
 *
 * Reserved for screens like /admin/users and /admin/audit-logs that are
 * administrative in nature rather than tied to one action - a future role
 * that is granted USER_MANAGE without being ADMIN should not automatically
 * gain these screens too. Where a screen maps cleanly onto one permission
 * (e.g. /users/register -> USER_MANAGE), prefer permissionGuard instead: it
 * stays correct if the permission is ever regranted to a different role,
 * where a role name hard-coded here would not.
 *
 * Same two-refusal shape as permissionGuard: not signed in goes to /login
 * with a returnUrl, signed in but missing the role goes to /dashboard.
 * This is convenience only - the backend re-checks the underlying
 * permission with @PreAuthorize on every request regardless of role name.
 *
 * @example
 * canActivate: [authGuard, roleGuard(['ADMIN'])]
 */
export const roleGuard = (roles: string[]): CanActivateFn => {
  return (_route, state) => {
    const authService = inject(AuthService);
    const router = inject(Router);

    if (!authService.isAuthenticated()) {
      return router.createUrlTree(['/login'], { queryParams: { returnUrl: state.url } });
    }

    if (roles.some((role) => authService.hasRole(role))) {
      return true;
    }

    return router.createUrlTree(['/dashboard']);
  };
};
