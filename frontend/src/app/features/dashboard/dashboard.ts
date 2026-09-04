import { Component, inject } from '@angular/core';
import { RouterLink } from '@angular/router';
import { Permissions } from '../../core/models/permissions';
import { AuthService } from '../../core/services/auth.service';

/**
 * Minimal landing page behind authGuard - just enough to prove the login
 * round trip end to end (who signed in, what they can do, sign out). The
 * real dashboard is a separate piece of work; this only exists so /login has
 * somewhere real to send a successful sign-in.
 */
@Component({
  selector: 'app-dashboard',
  imports: [RouterLink],
  templateUrl: './dashboard.html',
  styleUrl: './dashboard.css',
})
export class Dashboard {
  protected readonly authService = inject(AuthService);

  /** Mirrors the permissionGuard on /users/register - hide what they cannot open. */
  protected canManageUsers(): boolean {
    return this.authService.hasPermission(Permissions.USER_MANAGE);
  }

  protected logout(): void {
    this.authService.logout();
  }
}
