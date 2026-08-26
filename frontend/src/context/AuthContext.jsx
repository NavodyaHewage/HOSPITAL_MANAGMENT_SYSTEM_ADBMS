import { createContext, useContext, useMemo, useState } from 'react';
import authApi from '../features/auth/api/authApi';

const AuthContext = createContext(null);

export function AuthProvider({ children }) {
  const [user, setUser] = useState(() => {
    const stored = localStorage.getItem('hms_user');
    return stored ? JSON.parse(stored) : null;
  });

  const login = async (credentials) => {
    const data = await authApi.login(credentials);
    localStorage.setItem('hms_access_token', data.accessToken);
    localStorage.setItem('hms_user', JSON.stringify(data.user));
    setUser(data.user);
    return data.user;
  };

  const logout = () => {
    localStorage.removeItem('hms_access_token');
    localStorage.removeItem('hms_user');
    setUser(null);
  };

  const hasPermission = (permission) => user?.permissions?.includes(permission) ?? false;

  const value = useMemo(() => ({ user, login, logout, hasPermission }), [user]);
  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}

export const useAuth = () => useContext(AuthContext);
