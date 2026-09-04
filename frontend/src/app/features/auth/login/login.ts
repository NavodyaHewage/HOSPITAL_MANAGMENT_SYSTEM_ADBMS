import { Component, inject, signal } from '@angular/core';
import { HttpErrorResponse } from '@angular/common/http';
import { ReactiveFormsModule, Validators, NonNullableFormBuilder } from '@angular/forms';
import { ActivatedRoute, Router } from '@angular/router';
import { AuthService } from '../../../core/services/auth.service';
import { ApiResponse } from '../../../core/models/api-response.model';

@Component({
  selector: 'app-login',
  imports: [ReactiveFormsModule],
  templateUrl: './login.html',
  styleUrl: './login.css',
})
export class Login {
  private readonly fb = inject(NonNullableFormBuilder);
  private readonly authService = inject(AuthService);
  private readonly router = inject(Router);
  private readonly route = inject(ActivatedRoute);

  protected readonly isSubmitting = signal(false);
  protected readonly errorMessage = signal<string | null>(null);
  protected readonly showPassword = signal(false);

  /** max lengths mirror LoginRequest's @Size(max = 50/255) on the backend. */
  protected readonly form = this.fb.group({
    username: ['', [Validators.required, Validators.maxLength(50)]],
    password: ['', [Validators.required, Validators.maxLength(255)]],
  });

  protected togglePasswordVisibility(): void {
    this.showPassword.update((visible) => !visible);
  }

  protected submit(): void {
    if (this.form.invalid || this.isSubmitting()) {
      this.form.markAllAsTouched();
      return;
    }

    this.isSubmitting.set(true);
    this.errorMessage.set(null);

    this.authService.login(this.form.getRawValue()).subscribe({
      next: () => {
        const returnUrl = this.route.snapshot.queryParamMap.get('returnUrl') ?? '/dashboard';
        void this.router.navigateByUrl(returnUrl);
      },
      error: (error: unknown) => {
        this.isSubmitting.set(false);
        this.errorMessage.set(this.resolveErrorMessage(error));
      },
    });
  }

  /**
   * Every failure the backend raises for this call - bad credentials (401,
   * deliberately worded the same for "no such user" and "wrong password" so
   * a caller can't tell which usernames are real), a deactivated account
   * (also 401, same message, for the same reason), or a validation failure
   * (400) - arrives in the same ApiResponse envelope with a human-readable
   * `message`. A request that never reached that envelope (backend down,
   * blocked by CORS) reports HTTP status 0 and gets a distinct fallback.
   */
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
