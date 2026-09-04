import { Injectable, inject } from '@angular/core';
import { HttpClient, HttpParams } from '@angular/common/http';
import { Observable } from 'rxjs';
import { environment } from '../../../environments/environment';
import { ApiResponse } from '../models/api-response.model';
import { AuditLogResponse } from '../models/audit-log.model';
import { PageResponse } from '../models/page-response.model';

/**
 * Read-only, matching AuditController: audit rows are written by database
 * triggers inside the transaction they describe, so there is no create,
 * update or delete here to mirror.
 */
@Injectable({ providedIn: 'root' })
export class AuditService {
  private readonly http = inject(HttpClient);
  private readonly baseUrl = `${environment.apiUrl}/audit`;

  /** Newest first (the backend sorts by created_at descending). */
  search(page: number, size: number): Observable<ApiResponse<PageResponse<AuditLogResponse>>> {
    const params = new HttpParams().set('page', page).set('size', size);
    return this.http.get<ApiResponse<PageResponse<AuditLogResponse>>>(`${this.baseUrl}/logs`, { params });
  }
}
