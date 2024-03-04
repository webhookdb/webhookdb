import { apiFetch, apiFetchJson } from "./utils";

// In some cases we want to throw away the response body,
// like to avoid indicating a custom redirect after login or logout.
const emptyResolve = () => Promise.resolve();

export default function apiAuthProvider() {
  return {
    login: ({ username, password }) =>
      apiFetchJson(
        `/admin_api/v1/auth/login`,
        { email: username, password },
        { method: "POST" },
      ).then(emptyResolve),
    logout: () => apiFetch(`/v1/auth/logout`, { method: "POST" }).then(emptyResolve),
    checkAuth: () => apiFetch(`/admin_api/v1/auth`, { method: "GET" }).then(emptyResolve),
    checkError: (error) => {
      const status = error.status;
      if (status === 401) {
        // console.log("checkError: rejecting");
        return Promise.reject();
      }
      // other error code (404, 500, etc): no need to log out
      // console.log("checkError: resolving", status);
      return Promise.resolve();
    },
    getIdentity: () => apiFetchJson(`/admin_api/v1/auth`, null, { method: "GET" }),
    getPermissions: () => Promise.resolve(""),
  };
}
