import React from "react";

export function SafeExternalLink(props) {
  return <a target="_blank" {...props} />;
}

export function UnsafeExternalLink(props) {
  return <a target="_blank" rel="noreferrer" {...props} />;
}
