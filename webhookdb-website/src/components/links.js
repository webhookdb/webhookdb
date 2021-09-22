import React from "react";

export function Link({ className, ...rest }) {
  return <a className={className} {...rest} />;
}

export function SafeExternalLink(props) {
  return <Link target="_blank" {...props} />;
}

export function UnsafeExternalLink(props) {
  return <Link target="_blank" rel="noreferrer" {...props} />;
}
