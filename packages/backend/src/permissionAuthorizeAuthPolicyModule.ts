/**
 * The default HTTP credentials barrier (see createCredentialsBarrier in @backstage/backend-defaults)
 * only allows `user` and `service` principals unless a route opts in via addAuthPolicy. The
 * permission plugin only marks `/health` as unauthenticated, so `POST /authorize` was blocked
 * before the router ran — 401 "Missing credentials" for guest / unauthenticated callers.
 *
 * This module allows the authorize handler to run; it still performs its own
 * httpAuth.credentials(req, { allow: ["user", "none"] }) checks.
 */
import {
  coreServices,
  createBackendModule,
} from '@backstage/backend-plugin-api';

export default createBackendModule({
  pluginId: 'permission',
  moduleId: 'authorize-route-auth-policy',
  register(env) {
    env.registerInit({
      deps: {
        httpRouter: coreServices.httpRouter,
      },
      async init({ httpRouter }) {
        httpRouter.addAuthPolicy({
          path: '/authorize',
          allow: 'unauthenticated',
        });
      },
    });
  },
});
