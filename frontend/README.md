# Frontend — React + Vite

## Layout

```
src/
├── main.jsx              entry: QueryClient, Router, AuthProvider
├── app/App.jsx
├── api/                  axiosClient (JWT + error interceptors), endpoints
├── routes/               AppRoutes, ProtectedRoute (login + permission gate)
├── layouts/              MainLayout (sidebar + topbar shell)
├── context/              AuthContext
├── components/           ui/ common/ tables/ forms/ charts/
├── features/<feature>/
│   ├── api/              endpoint calls for that feature
│   ├── hooks/            TanStack Query hooks
│   ├── components/       feature-local components
│   └── pages/            routed pages
├── hooks/  store/  services/  utils/  constants/  types/
└── assets/               images, styles
```

Features: `auth`, `dashboard`, `patients`, `doctors`, `departments`,
`appointments`, `consultations`, `prescriptions`, `laboratory`, `pharmacy`,
`billing`, `users`, `audit`, `reports`.

`features/patients` is wired end to end (api, hook, page) as the reference
pattern.

## Conventions

- Server state lives in TanStack Query, not in context or Redux. Context holds
  only the authenticated user.
- Every request goes through `api/axiosClient`; it attaches the JWT and unwraps
  the `ApiResponse` envelope. A 409 carries a database rule message, so show it
  to the user as-is.
- Navigation and buttons are gated with `hasPermission(...)` using the same
  permission names the backend checks.
