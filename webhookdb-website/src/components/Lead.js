import React from "react";
import clsx from "clsx";

export default function Lead({ className, ...rest }) {
  const cls = clsx("lead", className);
  return <p className={cls} {...rest} />;
}
