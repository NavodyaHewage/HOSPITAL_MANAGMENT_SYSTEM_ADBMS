import { useAuth } from '../../context/AuthContext';

export default function Topbar() {
  const { user, logout } = useAuth();

  return (
    <header className="topbar">
      <span>{user?.fullName}</span>
      <button type="button" onClick={logout}>
        Log out
      </button>
    </header>
  );
}
