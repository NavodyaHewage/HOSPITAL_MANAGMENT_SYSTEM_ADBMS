import { Navigate, Outlet } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';

/** Gate a route on login and, optionally, on one permission name. */
export default function ProtectedRoute({ permission }) {
  const { user, hasPermission } = useAuth();

  if (!user) return <Navigate to="/login" replace />;
  if (permission && !hasPermission(permission)) return <Navigate to="/403" replace />;
  return <Outlet />;
}
