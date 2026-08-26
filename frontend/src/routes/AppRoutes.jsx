import { Route, Routes, Navigate } from 'react-router-dom';
import MainLayout from '../layouts/MainLayout';
import ProtectedRoute from './ProtectedRoute';
import { PERMISSIONS } from '../constants/roles';

import LoginPage from '../features/auth/pages/LoginPage';
import DashboardPage from '../features/dashboard/pages/DashboardPage';
import PatientListPage from '../features/patients/pages/PatientListPage';

export default function AppRoutes() {
  return (
    <Routes>
      <Route path="/login" element={<LoginPage />} />

      <Route element={<ProtectedRoute />}>
        <Route element={<MainLayout />}>
          <Route path="/" element={<Navigate to="/dashboard" replace />} />
          <Route path="/dashboard" element={<DashboardPage />} />

          <Route element={<ProtectedRoute permission={PERMISSIONS.PATIENT_READ} />}>
            <Route path="/patients" element={<PatientListPage />} />
          </Route>

          {/* appointments, consultations, prescriptions, laboratory,
              pharmacy, billing, users, audit and reports mount here */}
        </Route>
      </Route>

      <Route path="/403" element={<p>You do not have permission to view this page.</p>} />
      <Route path="*" element={<p>404 - Not found</p>} />
    </Routes>
  );
}
