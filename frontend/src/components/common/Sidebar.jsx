import { NavLink } from 'react-router-dom';
import { PERMISSIONS } from '../../constants/roles';
import { useAuth } from '../../context/AuthContext';

const NAV_ITEMS = [
  { to: '/dashboard', label: 'Dashboard' },
  { to: '/patients', label: 'Patients', permission: PERMISSIONS.PATIENT_READ },
  { to: '/appointments', label: 'Appointments', permission: PERMISSIONS.APPOINTMENT_BOOK },
  { to: '/consultations', label: 'Consultations', permission: PERMISSIONS.CONSULTATION_WRITE },
  { to: '/laboratory', label: 'Laboratory', permission: PERMISSIONS.LAB_ORDER },
  { to: '/pharmacy', label: 'Pharmacy', permission: PERMISSIONS.PHARMACY_DISPENSE },
  { to: '/billing', label: 'Billing', permission: PERMISSIONS.BILLING_WRITE },
  { to: '/users', label: 'Users', permission: PERMISSIONS.USER_MANAGE },
  { to: '/audit', label: 'Audit Log', permission: PERMISSIONS.AUDIT_READ },
  { to: '/reports', label: 'Reports', permission: PERMISSIONS.REPORT_VIEW },
];

export default function Sidebar() {
  const { hasPermission } = useAuth();

  return (
    <aside className="sidebar">
      <h1 className="sidebar-brand">HMS</h1>
      <nav>
        {NAV_ITEMS.filter((item) => !item.permission || hasPermission(item.permission)).map((item) => (
          <NavLink key={item.to} to={item.to}>
            {item.label}
          </NavLink>
        ))}
      </nav>
    </aside>
  );
}
