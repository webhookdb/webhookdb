import React from "react";
import toast, { Toaster as RHToaster } from "react-hot-toast";

export default function Toaster() {
  React.useEffect(() => {
    const callback = () => {
      toast.remove();
    };
    window.addEventListener("popstate", callback);
    return () => window.removeEventListener("popstate", callback);
  }, []);

  return <RHToaster />;
}
