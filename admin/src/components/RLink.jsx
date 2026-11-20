import React from "react";
import { Link as RouterLink } from "react-router-dom";

const RLink = React.forwardRef(function RLink(props, ref) {
  const { href, ...other } = props;
  // Map href (MUI) -> to (react-router)
  return <RouterLink ref={ref} to={href} {...other} />;
});

export default RLink;
