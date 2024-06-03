import React from "react";
import useUser from "./useUser.jsx";

export default function useRoleAccess({ forceReadAll } = {}) {
  const { user } = useUser();
  const roleAccess = user?.activeOrganization?.roleAccess;
  const canAccess = React.useCallback(
    (name, access) => {
      if (!roleAccess) {
        return false;
      }
      return roleAccess[name]?.includes(access);
    },
    [roleAccess],
  );
  const canRead = React.useCallback(
    (name) => forceReadAll || canAccess(name, "read"),
    [forceReadAll, canAccess],
  );
  const canWrite = React.useCallback(
    (name) => canAccess(name, "write"),
    [canAccess],
  );
  const cannotWrite = React.useCallback(
    (name) => !canAccess(name, "write"),
    [canAccess],
  );

  const result = React.useMemo(
    () => ({ canAccess, canRead, canWrite, cannotWrite }),
    [canAccess, canRead, canWrite, cannotWrite],
  );
  return result;
}
