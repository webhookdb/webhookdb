import { Link } from "gatsby";
import React from "react";

export default function RLink({ href, to, ...rest }) {
  return <Link to={to || href || "#"} {...rest} />;
}
