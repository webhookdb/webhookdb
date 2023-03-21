import { Link } from "gatsby";
import React from "react";

export default function RLink({ href, to, ...rest }) {
  const a = to || href || "#";
  if (a.startsWith("http://") || a.startsWith("https://")) {
    return <a href={a} target="_self" {...rest} />;
  }
  return <Link to={to || href || "#"} {...rest} />;
}
