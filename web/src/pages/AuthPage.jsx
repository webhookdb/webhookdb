import logo from "../assets/images/webhookdb-logo-512.png";
import Layout from "../components/Layout";
import StateMachineForm from "../components/StateMachineForm";
import FormButtons from "../components/uikit/FormButtons";
import Stack from "../components/uikit/Stack";
import TextField from "../components/uikit/TextField";
import { RelLink } from "../components/uikit/links";

export default function AuthPage() {
  // function handleSubmit(e) {
  //   prepareSubmit(e);
  //   api
  //     .login(state)
  //     .then((r) => {
  //       setUser(r.data);
  //       navigate("/dashboard");
  //     })
  //     .catch(handleSubmitError);
  // }

  // function handleChange(e) {
  //   setState({ ...state, [e.target.name]: e.target.value });
  // }

  return (
    <Layout noNav>
      <Stack gap={5} className="align-center">
        <RelLink href="/">
          <img src={logo} alt="logo" width={75} className="mt-5" />
        </RelLink>
        <h3 className="text-center max-width-sm">Welcome to WebhookDB!</h3>
        <StateMachineForm
          url="/v1/auth"
          className="p-4"
          style={{ width: 300 }}
          defaultState={{ email: "" }}
        >
          {({ onChange, state }) => (
            <>
              <h6 className="mb-5">Please sign in to continue.</h6>
              <TextField
                label="Email address"
                wide
                value={state.email}
                name="email"
                type="email"
                placeholder="Enter email"
                autoComplete="email"
                onChange={onChange}
              />
            </>
          )}
        </StateMachineForm>
      </Stack>
    </Layout>
  );
}
