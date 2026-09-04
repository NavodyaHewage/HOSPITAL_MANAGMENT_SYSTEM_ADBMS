import { Component, OnInit, inject, signal } from '@angular/core';
import { HttpErrorResponse } from '@angular/common/http';
import { RouterLink } from '@angular/router';
import { ApiResponse } from '../../../core/models/api-response.model';
import { AuditLogResponse } from '../../../core/models/audit-log.model';
import { AuditService } from '../../../core/services/audit.service';

const PAGE_SIZE = 25;

@Component({
  selector: 'app-audit-log-viewer',
  imports: [RouterLink],
  templateUrl: './audit-log-viewer.html',
  styleUrl: '../admin-shared.css',
})
export class AuditLogViewer implements OnInit {
  private readonly auditService = inject(AuditService);

  protected readonly logs = signal<AuditLogResponse[]>([]);
  protected readonly isLoading = signal(true);
  protected readonly errorMessage = signal<string | null>(null);
  protected readonly page = signal(0);
  protected readonly totalPages = signal(0);
  protected readonly totalElements = signal(0);

  ngOnInit(): void {
    this.loadPage(0);
  }

  protected loadPage(page: number): void {
    this.isLoading.set(true);
    this.errorMessage.set(null);

    this.auditService.search(page, PAGE_SIZE).subscribe({
      next: (response) => {
        const data = response.data;
        this.logs.set(data?.content ?? []);
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

  /** Lowercased for a CSS class: admin-action--insert, --update, --delete, --login, --logout. */
  protected actionClass(action: AuditLogResponse['action']): string {
    return action ? `admin-action--${action.toLowerCase()}` : '';
  }

  /**
   * INSERT/LOGIN/LOGOUT rows carry only new_value; DELETE carries only
   * old_value; UPDATE carries both, shown as "before -> after" so the change
   * is legible without opening a details view.
   */
  protected details(log: AuditLogResponse): string {
    if (log.action === 'UPDATE' && log.oldValue && log.newValue) {
      return `${log.oldValue} → ${log.newValue}`;
    }
    return log.newValue || log.oldValue || '—';
  }

  protected formatTimestamp(value: string): string {
    return new Date(value).toLocaleString(undefined, {
      year: 'numeric',
      month: 'short',
      day: 'numeric',
      hour: '2-digit',
      minute: '2-digit',
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
