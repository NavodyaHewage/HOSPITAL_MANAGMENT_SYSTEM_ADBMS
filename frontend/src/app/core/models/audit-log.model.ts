/** Mirrors com.hospital.hms.module.audit.dto.response.AuditLogResponse. */
export interface AuditLogResponse {
  logId: number;
  userId: number | null;
  username: string | null;
  entityName: string;
  entityId: number | null;
  action: 'INSERT' | 'UPDATE' | 'DELETE' | 'LOGIN' | 'LOGOUT' | null;
  oldValue: string | null;
  newValue: string | null;
  ipAddress: string | null;
  createdAt: string;
}
