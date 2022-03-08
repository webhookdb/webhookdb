import "../styles/custom.scss";

import { Button, Form, Modal } from "react-bootstrap";

import React from "react";

export default function useContactUs() {
  const [showContactUs, setContactUs] = React.useState(false);
  const closeContactUs = React.useCallback(() => setContactUs(false), []);
  const openContactUs = React.useCallback(() => setContactUs(true), []);
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
  return (
    <Modal show={showContactUs} onHide={closeContactUs} animation={true} centered>
      <Modal.Header closeButton>
        <Modal.Title>Contact Us</Modal.Title>
      </Modal.Header>
      <Modal.Body>
        <ContactForm />
      </Modal.Body>
    </Modal>
  );
}

function ContactForm() {
  return (
    <div id="contact">
      <div>
        <p>
          Email us at <a href="mailto:webhookdb@lithic.tech">webhookdb@lithic.tech</a>{" "}
          or use this form:
        </p>
        <Form
          as="form"
          method="POST"
          action="/contact-success"
          encType="multipart/form-data"
          data-netlify="true"
          data-netlify-honeypot="bot-field"
        >
          <Form.Group>
            <Form.Label>Name</Form.Label>
            <Form.Control required type="name" />
          </Form.Group>
          <Form.Group controlId="formBasicEmail">
            <Form.Label>Email address</Form.Label>
            <Form.Control required type="email" />
            <Form.Text className="text-muted">
              We&rsquo;ll never share your email with anyone else.
            </Form.Text>
          </Form.Group>
          <Form.Group>
            <Form.Label>Message</Form.Label>
            <Form.Control as="textarea" type="textarea" rows={3} />
          </Form.Group>
          <Button className="mr-3 px-5" variant="primary" type="submit">
            Submit
          </Button>
          <Button variant="outline-primary" type="reset">
            Clear
          </Button>
        </Form>
      </div>
    </div>
  );
}
