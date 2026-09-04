import { Component, computed, inject } from '@angular/core';
import { RouterLink } from '@angular/router';
import { Permissions } from '../../core/models/permissions';
import { Roles } from '../../core/models/roles';
import { AuthService } from '../../core/services/auth.service';

interface AdminTile {
  readonly title: string;
  readonly description: string;
  readonly link: string;
  readonly linkLabel: string;
  readonly icon: string;
}

/**
 * Landing page behind authGuard. The Administration grid mirrors the route
 * guards exactly, tile by tile, rather than one blanket "isAdmin" check:
 * User Registration is gated on the USER_MANAGE permission (matching
 * permissionGuard on /users/register) while User Management and Audit Logs
 * are gated on the ADMIN role (matching roleGuard on their routes). A tile
 * only ever appears when the route behind it will actually open.
 */
@Component({
  selector: 'app-dashboard',
  imports: [RouterLink],
  templateUrl: './dashboard.html',
  styleUrl: './dashboard.css',
})
export class Dashboard {
  protected readonly authService = inject(AuthService);

  protected readonly initial = computed(() => (this.authService.currentUser()?.fullName ?? '?').charAt(0).toUpperCase());

  protected canManageUsers(): boolean {
    return this.authService.hasPermission(Permissions.USER_MANAGE);
  }

  protected isAdmin(): boolean {
    return this.authService.hasRole(Roles.ADMIN);
  }

  protected hasAdminAccess(): boolean {
    return this.canManageUsers() || this.isAdmin();
  }

  protected readonly adminTiles: readonly AdminTile[] = [
    {
      title: 'User Registration',
      description: 'Create a new staff account and assign its role in one transaction.',
      link: '/users/register',
      linkLabel: 'Register New User',
      icon: '➕',
    },
    {
      title: 'User Management',
      description: 'View every system user, their role and status, and enable or disable accounts.',
      link: '/admin/users',
      linkLabel: 'Manage System Users',
      icon: '👥',
    },
    {
      title: 'Audit Logs',
      description: 'Review every recorded database change - who did what, and when.',
      link: '/admin/audit-logs',
      linkLabel: 'View Activity Logs',
      icon: '📋',
    },
  ];

  /** Each tile still checks its own authority - see the class-level note above. */
  protected canOpen(tile: AdminTile): boolean {
    if (tile.link === '/users/register') {
      return this.canManageUsers();
    }
    return this.isAdmin();
  }

  protected logout(): void {
    this.authService.logout();
  }
}
