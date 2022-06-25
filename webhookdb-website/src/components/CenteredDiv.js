import React from "react";
import clsx from "clsx";

export default function CenteredDiv({ className, children }) {
  return (
    <div className={clsx("d-flex flex-row justify-content-center", className)}>
      {children}
    </div>
  );
}
