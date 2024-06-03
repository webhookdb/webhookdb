import React from "react";

/**
 * Just a `React.useEffect(cb, [])` that is more declarative than
 * doing it in line and disabling eslint.
 * @param cb
 */
export default function useMountEffect(cb) {
  // eslint-disable-next-line react-hooks/exhaustive-deps
  React.useEffect(cb, []);
}
