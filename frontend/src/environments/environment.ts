/**
 * Production defaults. Swapped in for development builds via the
 * "development" fileReplacements entry in angular.json - see
 * environment.development.ts.
 *
 * A relative apiUrl assumes the built Angular app and the Spring Boot
 * backend are served from the same origin (e.g. behind a reverse proxy, or
 * the backend serving the built frontend as static content). If they are
 * deployed on separate origins, replace this with the backend's absolute
 * URL and add that origin to app.cors.allowed-origins in the backend's
 * application.properties.
 */
export const environment = {
  production: true,
  apiUrl: '/api',
};
