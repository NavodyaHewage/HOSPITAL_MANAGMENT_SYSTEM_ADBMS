/** Mirrors security/rbac/RoleName.java - the seven roles seeded into `roles`. */
export const Roles = {
  ADMIN: 'ADMIN',
  DOCTOR: 'DOCTOR',
  NURSE: 'NURSE',
  PHARMACIST: 'PHARMACIST',
  CASHIER: 'CASHIER',
  LAB_TECH: 'LAB_TECH',
  RECEPTIONIST: 'RECEPTIONIST',
} as const;

export type Role = (typeof Roles)[keyof typeof Roles];
