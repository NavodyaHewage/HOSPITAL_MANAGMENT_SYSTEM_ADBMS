/**
 * Mirrors security/rbac/Permissions.java, which itself mirrors the seeded
 * `permissions` table (see PermissionsIntegrityTest on the backend). Keep
 * this list in the same order and spelling as that file - a permission name
 * used here that the backend does not grant will simply never be true.
 */
export const Permissions = {
  PATIENT_READ: 'PATIENT_READ',
  PATIENT_WRITE: 'PATIENT_WRITE',
  APPOINTMENT_BOOK: 'APPOINTMENT_BOOK',
  CONSULT_WRITE: 'CONSULT_WRITE',
  PRESCRIBE: 'PRESCRIBE',
  LAB_ORDER: 'LAB_ORDER',
  LAB_RESULT_WRITE: 'LAB_RESULT_WRITE',
  BILL_CREATE: 'BILL_CREATE',
  PAYMENT_RECORD: 'PAYMENT_RECORD',
  STOCK_RECEIVE: 'STOCK_RECEIVE',
  STOCK_DISPENSE: 'STOCK_DISPENSE',
  AUDIT_READ: 'AUDIT_READ',
  USER_MANAGE: 'USER_MANAGE',
} as const;

export type Permission = (typeof Permissions)[keyof typeof Permissions];
