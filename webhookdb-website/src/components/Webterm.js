import React from "react";
import clsx from "clsx";

export default function Webterm({ className, ...rest }) {
  const cls = clsx("border-0", className);
  return (
    <iframe
      src="/webterm/index.html"
      className={cls}
      title="WebhookDB Interactive Terminal"
      {...rest}
    />
  );
}
