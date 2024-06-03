import { initSentry } from "./modules/sentry";

// When we are serving from the backend, only use the config it provides.
// Otherwise we could accidentally template in values at build time (on staging)
// and carry them forward to runtime in a different env (on prod).
// We won't have whdbDynamicEnv set when running
// the development server of React during local dev,
// or if this app is built and deployed separately as a static app.
const env = window.whdbDynamicEnv || import.meta.env;

// If the API host is configured, use that.
// If it's '/', assume we mean 'the same server',
// and use an empty string. Otherwise, fall back to local dev,
// which is usually a different server to the dev server.
let apiHost = env.VITE_API_ROOT;
if (apiHost === "/") {
  apiHost = "";
} else if (!apiHost) {
  apiHost = `http://localhost:18001`;
}

const config = {
  apiHost: apiHost,
  chaos: env.VITE_CHAOS || false,
  debug: env.VITE_DEBUG || false,
  environment: env.NODE_ENV || "development",
  releaseCommit: env.VITE_RELEASE_COMMIT || "000000",
  sentryDsn: env.VITE_SENTRY_DSN || "",
  sentryTunnel: env.VITE_SENTRY_TUNNEL || "",
  styleguide: env.VITE_STYLEGUIDE || false,
};

initSentry({
  dsn: config.sentryDsn,
  debug: config.debug,
  application: "webhookdb-web",
  release: `webhookdb-web@${config.releaseCommit}`,
  tunnel: config.sentryTunnel,
});

export default config;
