import { Routes } from '@angular/router';
import { authGuard } from './core/guards/auth.guard';
import { guestGuard } from './core/guards/guest.guard';
import { permissionGuard } from './core/guards/permission.guard';
import { roleGuard } from './core/guards/role.guard';
import { Permissions } from './core/models/permissions';
import { Roles } from './core/models/roles';

export const routes: Routes = [
  {
    path: 'login',
    canActivate: [guestGuard],
    loadComponent: () => import('./features/auth/login/login').then((m) => m.Login),
  },
  {
    path: 'dashboard',
    canActivate: [authGuard],
    loadComponent: () => import('./features/dashboard/dashboard').then((m) => m.Dashboard),
  },
  {
    path: 'users/register',
    canActivate: [permissionGuard(Permissions.USER_MANAGE)],
    loadComponent: () => import('./features/users/register/register').then((m) => m.Register),
  },
  {
    path: 'admin/users',
    canActivate: [authGuard, roleGuard([Roles.ADMIN])],
    loadComponent: () =>
      import('./features/admin/users/user-management').then((m) => m.UserManagement),
  },
  {
    path: 'admin/audit-logs',
    canActivate: [authGuard, roleGuard([Roles.ADMIN])],
    loadComponent: () =>
      import('./features/admin/audit-logs/audit-log-viewer').then((m) => m.AuditLogViewer),
  },
  { path: '', pathMatch: 'full', redirectTo: 'dashboard' },
  { path: '**', redirectTo: 'dashboard' },
];
