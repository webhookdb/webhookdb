import "../styles/custom.scss";

import { Button, Form } from "react-bootstrap";

import React from "react";

export default function ContactForm({
  state,
  setState,
  onSubmitted,
  hideEmail,
  alt,
  className,
}) {
  const [disabled, setDisabled] = React.useState(false);
  state = state || INITIAL_STATE;

  function handleChange(e) {
    setState({ ...state, [e.target.name]: e.target.value });
  }

  function handleClear(e) {
    e.preventDefault();
    setState(INITIAL_STATE);
  }

  function handleSubmit(e) {
    e.preventDefault();
    setDisabled(true);
    const body = {
      "form-name": "contact",
      ...state,
    };
    delete body.error;

    return fetch("/", {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body: formEncodeObject(body),
    })
      .then(() => onSubmitted && onSubmitted())
      .catch((error) => {
        console.error(error);
        setState({
          ...state,
          error:
            "Sorry, something went wrong. Please email hello@webhookdb.com to get in touch.",
        });
      })
      .finally(() => setDisabled(false));
  }

  return (
    <div id="contact" className={className}>
      <div>
        {!hideEmail && (
          <p>
            Email us at <a href="mailto:hello@webhookdb.com">hello@webhookdb.com</a> or
            use this form:
          </p>
        )}
        <Form as="form" name="contact" onSubmit={handleSubmit}>
          <input
            type="text"
            className="d-none"
            name="totallyreal"
            value={state.totallyreal}
            onChange={handleChange}
          />
          <Form.Group controlId="name">
            <Form.Label>Name</Form.Label>
            <Form.Control
              required
              type="name"
              name="name"
              value={state.name}
              onChange={handleChange}
            />
          </Form.Group>
          <Form.Group controlId="email">
            <Form.Label>Email address</Form.Label>
            <Form.Control
              required
              type="email"
              name="email"
              value={state.email}
              onChange={handleChange}
            />
            <Form.Text className={alt ? "text-light" : "text-muted"}>
              We&rsquo;ll never share your email with anyone else.
            </Form.Text>
          </Form.Group>
          <Form.Group controlId="message">
            <Form.Label>Message</Form.Label>
            <Form.Control
              as="textarea"
              type="textarea"
              name="message"
              rows={3}
              value={state.message}
              onChange={handleChange}
            />
          </Form.Group>
          {state.error && (
            <div>
              <p>{state.error}</p>
            </div>
          )}
          <div className="d-flex justify-content-end">
            <Button
              variant={alt ? "outline-light" : "outline-primary"}
              type="reset"
              onClick={handleClear}
            >
              Clear
            </Button>
            <Button
              className="ml-3 px-5"
              variant={alt ? "light" : "primary"}
              type="submit"
              disabled={disabled}
            >
              Submit
            </Button>
          </div>
        </Form>
      </div>
    </div>
  );
}

const INITIAL_STATE = { name: "", email: "", message: "", totallyreal: "", error: "" };

function formEncodeObject(data) {
  return Object.keys(data)
    .map((key) => encodeURIComponent(key) + "=" + encodeURIComponent(data[key]))
    .join("&");
}
