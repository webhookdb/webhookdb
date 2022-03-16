import "../styles/custom.scss";

import { Button, Form, Modal } from "react-bootstrap";

import React from "react";

export default function useContactUs() {
  const [showContactUs, setShowContactUs] = React.useState(false);
  const closeContactUs = React.useCallback(() => setShowContactUs(false), []);
  const openContactUs = React.useCallback(() => setShowContactUs(true), []);
  const renderContactUs = React.useCallback(
    () => <ContactUs showContactUs={showContactUs} closeContactUs={closeContactUs} />,
    [showContactUs, closeContactUs]
  );
  return {
    render: renderContactUs,
    open: openContactUs,
    close: closeContactUs,
  };
}

function ContactUs({ closeContactUs, showContactUs }) {
  const [state, setState] = React.useState(INITIAL_STATE);
  const [submitted, setSubmitted] = React.useState(false);

  function handleHide() {
    closeContactUs();
    window.setTimeout(() => {
      // We want to reset the form after it disappears from the DOM.
      // There are better ways to do this.
      setState(INITIAL_STATE);
      setSubmitted(false);
    }, 1000);
  }

  function handleSubmit(e) {
    e.preventDefault();
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
      .then(() => setSubmitted(true))
      .catch((error) => {
        console.error(error);
        setState({
          ...state,
          error:
            "Sorry, something went wrong. Please email webhookdb@lithic.tech to get in touch.",
        });
      });
  }

  return (
    <Modal show={showContactUs} onHide={handleHide} animation={true} centered>
      <Modal.Header closeButton>
        <Modal.Title>Contact Us</Modal.Title>
      </Modal.Header>
      <Modal.Body>
        {submitted ? (
          <div className="d-flex flex-column">
            <p>Thanks! We&rsquo;ll be in touch within the next business day.</p>
            <Button variant="primary" onClick={handleHide}>
              Close
            </Button>
          </div>
        ) : (
          <ContactForm state={state} setState={setState} onSubmit={handleSubmit} />
        )}
      </Modal.Body>
    </Modal>
  );
}

function ContactForm({ state, setState, onSubmit }) {
  const [disabled, setDisabled] = React.useState(false);

  function handleChange(e) {
    setState({ ...state, [e.target.name]: e.target.value });
  }

  function handleClear(e) {
    e.preventDefault();
    setState(INITIAL_STATE);
  }

  function handleSubmit(e) {
    setDisabled(true);
    onSubmit(e).finally(() => setDisabled(false));
  }

  return (
    <div id="contact">
      <div>
        <p>
          Email us at <a href="mailto:webhookdb@lithic.tech">webhookdb@lithic.tech</a>{" "}
          or use this form:
        </p>
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
            <Form.Text className="text-muted">
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
            <Button variant="outline-primary" type="reset" onClick={handleClear}>
              Clear
            </Button>
            <Button
              className="ml-3 px-5"
              variant="primary"
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

function formEncodeObject(data) {
  return Object.keys(data)
    .map((key) => encodeURIComponent(key) + "=" + encodeURIComponent(data[key]))
    .join("&");
}

const INITIAL_STATE = { name: "", email: "", message: "", totallyreal: "", error: "" };
