import React from "react";

import api from "../api";
import badContext from "../modules/badContext";
import { localStorageCache } from "../modules/localStorageHelper";
import { withSentry } from "../modules/sentry.js";

export const UserContext = React.createContext({
  user: { id: 0, email: "", activeOrganization: { id: 0, name: "" } },
  setUser: badContext("User", {}),
  userLoading: false,
  userError: null,
  userAuthed: false,
  userUnauthed: false,
});

export function UserProvider({ children }) {
  // Store the current user in the local storage cache.
  // Load from the cache optimistically; if we have a cached user,
  // use it immediately while we go and fetch from the backend.
  // This avoids blocking doing anything while we wait on the user,
  // which normally won't change in a meaningful way
  // (and when it does change, the app will react to its new state properly).
  const [user, setUserInner] = React.useState(
    localStorageCache.getItem(STORAGE_KEY, null),
  );
  const [userLoading, setUserLoading] = React.useState(!user);
  const [userError, setUserError] = React.useState(null);

  const setUser = React.useCallback((u) => {
    setUserInner(u);
    localStorageCache.setItem(STORAGE_KEY, u);
    setUserLoading(false);
    setUserError(null);
    withSentry((Sentry) => {
      if (!u) {
        Sentry.setUser(null);
      } else {
        Sentry.setUser({ id: u.id, email: u.email });
      }
    });
  }, []);

  const fetchUser = React.useCallback(() => {
    return api
      .getMe()
      .then(api.pickData)
      .then(setUser)
      .catch((e) => {
        setUserInner(null);
        localStorageCache.removeItem(STORAGE_KEY);
        setUserLoading(false);
        setUserError(e);
        withSentry((Sentry) => Sentry.setUser(null));
      });
  }, [setUser]);

  React.useEffect(() => {
    fetchUser().then(() => null);
  }, [fetchUser]);

  const value = React.useMemo(
    () => ({
      user,
      setUser,
      userLoading,
      userError,
      userAuthed: Boolean(user),
      userUnauthed: !userLoading && !user,
    }),
    [setUser, user, userError, userLoading],
  );

  return <UserContext.Provider value={value}>{children}</UserContext.Provider>;
}

const STORAGE_KEY = "whdbuser";
