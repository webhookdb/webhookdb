import { useState } from "react";
import { Link, useLocation, useNavigate } from "react-router-dom";

import api from "../../api";
import TextField from "../../components/uikit/TextField.jsx";
import useFormSubmitter from "../../state/useFormSubmitter.js";
import useQuery from "../../state/useQuery.jsx";
import useUser from "../../state/useUser.jsx";
import AuthLayout from "./../auth/AuthLayout.jsx";

export default function SigninPage() {
  const navigate = useNavigate();
  const { setUser } = useUser();
  const query = useQuery();
  const { state: locationState } = useLocation();
  const { prepareSubmit, handleSubmitError } = useFormSubmitter();
  const invitation = locationState?.invitation;
  const [state, setState] = useState({
    email: invitation?.email || "",
    password: "",
  });

  function handleSubmit(e) {
    prepareSubmit(e);
    api
      .login(state)
      .then((r) => {
        setUser(r.data);
        navigate("/dashboard");
      })
      .catch(handleSubmitError);
  }

  function handleChange(e) {
    setState({ ...state, [e.target.name]: e.target.value });
  }

  return (
    <AuthLayout
      heading={
        invitation ? (
          <span>
            {invitation.organizationName} invited you
            <br />
            to join them on WebhookDB
          </span>
        ) : (
          "Please sign in."
        )
      }
      formButtonProps={{
        submit: "Sign in",
        successMessage:
          query.get("verified") === "true" &&
          "Your email has been verified. Please log in.",
      }}
      footerLink={<Link to="/register">Or register a new account</Link>}
      onSubmit={handleSubmit}
    >
      <TextField
        label="Email address"
        wide
        value={state.email}
        name="email"
        type="email"
        placeholder="Enter email"
        autoComplete="email"
        readOnly={Boolean(invitation)}
        onChange={handleChange}
      />
      <TextField
        label="Password"
        wide
        marginTop
        name="password"
        value={state.password}
        type="password"
        placeholder="Password"
        autoComplete="current-password"
        className="mb-1"
        onChange={handleChange}
      />
      <p className="text-desc text-right w-100 mt-3">
        Do you need to <Link to="/forgot-password">reset your password</Link>?
      </p>
    </AuthLayout>
  );
}
