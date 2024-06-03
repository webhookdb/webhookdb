import { Navigate } from "react-router-dom";

export default function Redirect({ to, ...rest }) {
  return <Navigate replace to={to} {...rest} />;
}
