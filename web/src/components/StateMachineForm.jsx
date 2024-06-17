import { options } from "axios";
import React from "react";

import { Asker, StateMachine } from "../stateMachine";
import Button from "./uikit/Button";
import Form from "./uikit/Form";

export default function StateMachineForm({ url, defaultState, children, ...rest }) {
  const [state, setState] = React.useState(defaultState || {});
  const handleChange = React.useCallback(
    (e) => {
      const newState = { ...state, [e.target.name]: e.target.value };
      setState(newState);
    },
    [state],
  );
  const handleSubmit = React.useCallback(
    (e) => {
      e.preventDefault();
      const result = new StateMachine(new Asker()).makeRequest(url, state);
      console.log("asked", result);
    },
    [state, url],
  );
  return (
    <Form onSubmit={handleSubmit} {...rest}>
      {children({ onChange: handleChange, state })}
      <Button type="submit">Submit</Button>
    </Form>
  );
}

class FormAsker extends Asker {
  feedback(s) {
    super.feedback(s);
  }

  ask(prompt, options) {
    return super.ask(prompt, options);
  }
}
