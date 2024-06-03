import React from "react";

export default function ScrollTopOnMount({ top }) {
  React.useEffect(() => {
    // Not sure when or why this broke, but it seems like we need
    // to defer this call. This is just introducing a race condition,
    // so doesn't entirely fix the bug, but it's good enough to try for now.
    window.setTimeout(() => window.scrollTo(0, top || 0), 0);
  }, [top]);
  return null;
}
