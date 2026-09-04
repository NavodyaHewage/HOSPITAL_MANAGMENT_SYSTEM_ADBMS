import { RenderMode, ServerRoute } from '@angular/ssr';

/**
 * Auth state lives in the browser's localStorage (see TokenStorageService)
 * and is evaluated by authGuard/guestGuard at navigation time - there is no
 * request-scoped user on the server to render for, and prerendering
 * /dashboard at build time would freeze it in whatever the guard decides
 * with no session at all (a permanent redirect to /login). Every route in
 * this app renders on the client only.
 */
export const serverRoutes: ServerRoute[] = [{ path: '**', renderMode: RenderMode.Client }];
