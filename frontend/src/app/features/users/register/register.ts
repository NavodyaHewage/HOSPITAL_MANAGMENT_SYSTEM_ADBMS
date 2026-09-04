import { Component, computed, inject, signal } from '@angular/core';
import { HttpErrorResponse } from '@angular/common/http';
import { NonNullableFormBuilder, ReactiveFormsModule, Validators } from '@angular/forms';
import { RouterLink } from '@angular/router';
import { ApiResponse } from '../../../core/models/api-response.model';
import { Role, Roles } from '../../../core/models/roles';
import { UserResponse } from '../../../core/models/user.model';
import { UserService } from '../../../core/services/user.service';

interface RoleOption {
  readonly value: Role;
  readonly label: string;
  /** roles.description from the seed data - shown once a role is picked. */
  readonly description: string;
}

/** Matches CreateUserRequest's @Size(min = 3, max = 50) on username. */
const USERNAME_PATTERN = /^[a-zA-Z0-9._-]+$/;

/** Digits with optional spaces, dashes and a leading +, inside phone VARCHAR(20). */
const PHONE_PATTERN = /^\+?[0-9][0-9\s-]{6,19}$/;

@Component({
  selector: 'app-user-register',
  imports: [ReactiveFormsModule, RouterLink],
  templateUrl: './register.html',
  styleUrl: './register.css',
})
export class Register {
  private readonly fb = inject(NonNullableFormBuilder);
  private readonly userService = inject(UserService);

  protected readonly isSubmitting = signal(false);
  protected readonly errorMessage = signal<string | null>(null);
  protected readonly fieldErrors = signal<Record<string, string>>({});
  protected readonly registered = signal<UserResponse | null>(null);
  protected readonly showPassword = signal(false);

  protected readonly roleOptions: readonly RoleOption[] = [
    { value: Roles.ADMIN, label: 'Administrator', description: 'Full system access' },
    { value: Roles.DOCTOR, label: 'Doctor', description: 'Clinical access' },
    { value: Roles.NURSE, label: 'Nurse', description: 'Limited clinical access' },
    { value: Roles.PHARMACIST, label: 'Pharmacist', description: 'Inventory and dispensing' },
    { value: Roles.CASHIER, label: 'Cashier', description: 'Billing and payments' },
    { value: Roles.LAB_TECH, label: 'Lab Technician', description: 'Lab orders and results' },
    {
      value: Roles.RECEPTIONIST,
      label: 'Receptionist',
      description: 'Patient registration and appointments',
    },
  ];

  /**
   * Limits mirror CreateUserRequest's Bean Validation annotations so the form
   * rejects what the backend would reject, rather than round-tripping for a
   * 400 the user could have been told about immediately. Telephone is the one
   * deliberate difference: the column is nullable, but a staff account with no
   * contact number is not useful to a hospital, so it is required here.
   */
  protected readonly form = this.fb.group({
    fullName: ['', [Validators.required, Validators.minLength(3), Validators.maxLength(100)]],
    username: [
      '',
      [
        Validators.required,
        Validators.minLength(3),
        Validators.maxLength(50),
        Validators.pattern(USERNAME_PATTERN),
      ],
    ],
    password: ['', [Validators.required, Validators.minLength(8), Validators.maxLength(255)]],
    phone: ['', [Validators.required, Validators.pattern(PHONE_PATTERN)]],
    email: ['', [Validators.email, Validators.maxLength(100)]],
    roleName: ['' as Role | '', [Validators.required]],
  });

  /** Description of the currently selected role, for the hint under the dropdown. */
  protected readonly selectedRole = computed(() => this.form.controls.roleName.value);

  protected roleDescription(): string | null {
    const selected = this.roleOptions.find((role) => role.value === this.form.controls.roleName.value);
    return selected?.description ?? null;
  }

  protected togglePasswordVisibility(): void {
    this.showPassword.update((visible) => !visible);
  }

  /** Server-side field errors are cleared as soon as the user edits that field. */
  protected serverErrorFor(field: string): string | null {
    return this.fieldErrors()[field] ?? null;
  }

  protected clearServerError(field: string): void {
    const current = this.fieldErrors();
    if (current[field]) {
      const { [field]: _removed, ...rest } = current;
      this.fieldErrors.set(rest);
    }
  }

  protected registerAnother(): void {
    this.registered.set(null);
    this.form.reset({ roleName: '' });
  }

  protected submit(): void {
    if (this.form.invalid || this.isSubmitting()) {
      this.form.markAllAsTouched();
      return;
    }

    this.isSubmitting.set(true);
    this.errorMessage.set(null);
    this.fieldErrors.set({});

    const value = this.form.getRawValue();

    this.userService
      .createUser({
        fullName: value.fullName.trim(),
        username: value.username.trim(),
        password: value.password,
        phone: value.phone.trim(),
        // users.email is nullable and UNIQUE; '' would collide on the second
        // user left blank, so an empty box must be sent as null, not ''.
        email: value.email.trim() === '' ? null : value.email.trim(),
        roleName: value.roleName as Role,
      })
      .subscribe({
        next: (response) => {
          this.isSubmitting.set(false);
          this.registered.set(response.data);
          this.form.reset({ roleName: '' });
        },
        error: (error: unknown) => {
          this.isSubmitting.set(false);
          this.applyError(error);
        },
      });
  }

  /**
   * Three failure shapes reach this form, and each needs different treatment:
   * a 400 carries a field->message map in `data`, which belongs next to the
   * offending inputs; a 409 is the procedure's own rollback message
   * ('Username or email already exists') and belongs at the top; anything
   * that never reached the envelope reports status 0.
   */
  private applyError(error: unknown): void {
    if (!(error instanceof HttpErrorResponse)) {
      this.errorMessage.set('Something went wrong. Please try again.');
      return;
    }

    if (error.status === 0) {
      this.errorMessage.set('Unable to reach the server. Check your connection and try again.');
      return;
    }

    const body = error.error as ApiResponse<Record<string, string>> | null;

    if (error.status === 400 && body?.data) {
      this.fieldErrors.set(body.data);
      this.errorMessage.set(body.message ?? 'Please correct the highlighted fields.');
      return;
    }

    this.errorMessage.set(body?.message ?? 'Something went wrong. Please try again.');
  }
}
