/**
 * Used by `ng serve` (development is the default serve configuration).
 * Points straight at the locally running Spring Boot backend - see
 * backend/src/main/resources/application.properties (server.port=8080,
 * server.servlet.context-path=/api) and app.cors.allowed-origins, which must
 * include this Angular dev server's origin (http://localhost:4200).
 */
export const environment = {
  production: false,
  apiUrl: 'http://localhost:8080/api',
};
