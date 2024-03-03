const env = window.whdbDynamicEnv || import.meta.env;

// If the API host is configured, use that.
// If it's '/', assume we mean 'the same server',
// and use an empty string. Otherwise, fall back to local dev,
// which is usually a different server to the React dev server.
let apiHost = env.VITE_API_ROOT;
if (apiHost === "/") {
  apiHost = "";
} else if (!apiHost) {
  apiHost = `http://localhost:18001`;
}

const config = {
  apiHost: apiHost,
  environment: env.NODE_ENV || "development",
  releaseCommit: env.VITE_RELEASE_COMMIT || "000000",
  backendEnv: env.VITE_BACKEND_ENV || "development",
};

export default config;
