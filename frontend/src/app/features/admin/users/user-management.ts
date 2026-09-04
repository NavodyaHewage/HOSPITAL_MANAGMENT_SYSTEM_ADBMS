import { Component, OnInit, inject, signal } from '@angular/core';
import { HttpErrorResponse } from '@angular/common/http';
import { RouterLink } from '@angular/router';
import { ApiResponse } from '../../../core/models/api-response.model';
import { UserResponse } from '../../../core/models/user.model';
import { AuthService } from '../../../core/services/auth.service';
import { UserService } from '../../../core/services/user.service';

const PAGE_SIZE = 20;

@Component({
  selector: 'app-user-management',
  imports: [RouterLink],
  templateUrl: './user-management.html',
  styleUrl: '../admin-shared.css',
})
export class UserManagement implements OnInit {
  private readonly userService = inject(UserService);
  private readonly authService = inject(AuthService);

  protected readonly users = signal<UserResponse[]>([]);
  protected readonly isLoading = signal(true);
  protected readonly errorMessage = signal<string | null>(null);
  protected readonly page = signal(0);
  protected readonly totalPages = signal(0);
  protected readonly totalElements = signal(0);

  /** userId currently mid-toggle - disables that row's button so a double click can't fire two PATCHes. */
  protected readonly togglingUserId = signal<number | null>(null);

  ngOnInit(): void {
    this.loadPage(0);
  }

  protected loadPage(page: number): void {
    this.isLoading.set(true);
    this.errorMessage.set(null);

    this.userService.listUsers(page, PAGE_SIZE, true).subscribe({
      next: (response) => {
        const data = response.data;
        this.users.set(data?.content ?? []);
        this.page.set(data?.page ?? 0);
        this.totalPages.set(data?.totalPages ?? 0);
        this.totalElements.set(data?.totalElements ?? 0);
        this.isLoading.set(false);
      },
      error: (error: unknown) => {
        this.isLoading.set(false);
        this.errorMessage.set(this.resolveErrorMessage(error));
      },
    });
  }

  protected nextPage(): void {
    if (this.page() + 1 < this.totalPages()) {
      this.loadPage(this.page() + 1);
    }
  }

  protected previousPage(): void {
    if (this.page() > 0) {
      this.loadPage(this.page() - 1);
    }
  }

  /** A signed-in admin cannot disable their own account - that would lock them out with no one left to re-enable it. */
  protected isSelf(user: UserResponse): boolean {
    return this.authService.currentUser()?.userId === user.userId;
  }

  protected toggleStatus(user: UserResponse): void {
    if (this.togglingUserId() !== null || this.isSelf(user)) {
      return;
    }

    const nextActive = !user.isActive;
    this.togglingUserId.set(user.userId);

    this.userService.setActive(user.userId, nextActive).subscribe({
      next: () => {
        this.togglingUserId.set(null);
        this.users.update((list) =>
          list.map((u) => (u.userId === user.userId ? { ...u, isActive: nextActive } : u)),
        );
      },
      error: (error: unknown) => {
        this.togglingUserId.set(null);
        this.errorMessage.set(this.resolveErrorMessage(error));
      },
    });
  }

  protected formatDate(value: string | null): string {
    if (!value) {
      return '—';
    }
    return new Date(value).toLocaleDateString(undefined, {
      year: 'numeric',
      month: 'short',
      day: 'numeric',
    });
  }

  private resolveErrorMessage(error: unknown): string {
    if (error instanceof HttpErrorResponse) {
      if (error.status === 0) {
        return 'Unable to reach the server. Check your connection and try again.';
      }
      const body = error.error as ApiResponse<unknown> | null;
      if (body?.message) {
        return body.message;
      }
    }
    return 'Something went wrong. Please try again.';
  }
}
