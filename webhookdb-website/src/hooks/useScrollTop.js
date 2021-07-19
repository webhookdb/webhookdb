import React from "react";

export default function useScrollTop() {
  React.useEffect(() => {
    if (typeof window !== "undefined") {
      window.scroll(0, 0);
    }
  }, []);
}
