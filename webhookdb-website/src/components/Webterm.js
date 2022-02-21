import React from "react";
import clsx from "clsx";

export default function Webterm({ className, autofocus, ...rest }) {
  const cls = clsx("border-0", className);
  let src = `/webterm/index.html`;
  if (autofocus) {
    src += "?autofocus=1";
  }
  return (
    <iframe
      src={src}
      className={cls}
      title="WebhookDB Interactive Terminal"
      {...rest}
    />
  );
}
