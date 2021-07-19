import React from "react";
import "../styles/custom.scss";
import { Container, Image, Nav, Row, Col, Modal, Form, Button } from "react-bootstrap";
import Logo from "../images/blueonwhite.png";

export default function FooterSection() {
  const [showContactUs, setContactUs] = React.useState(false);
  const closeContactUs = () => setContactUs(false);
  const openContactUs = () => setContactUs(true);

  return (
    <Container fluid className={"bg-dark text-light p-3"}>
      <ContactUs closeContactUs={closeContactUs} showContactUs={showContactUs} />
      <Row className={"justify-content-center align-items-center"}>
        <Col>
          <Row className={"justify-content-center"}>
            <Nav defaultActiveKey="/" className="flex-row">
              <Nav.Link
                eventKey="link-1"
                className={"text-light"}
                onSelect={openContactUs}
              >
                Contact Us
              </Nav.Link>
              <Nav.Link eventKey="link-2" className={"text-light"} href={"/terms"}>
                Terms of Use
              </Nav.Link>
              <Nav.Link eventKey="link-2" className={"text-light"} href={"/privacy"}>
                Privacy Policy
              </Nav.Link>
            </Nav>
          </Row>
          <Row className={"justify-content-center my-3"}>
            <Image src={Logo} />
          </Row>
          <Row className={"justify-content-center my-3"}>
            <p> © {new Date().getFullYear()}</p>
          </Row>
        </Col>
      </Row>
    </Container>
  );
}

function ContactUs({ closeContactUs, showContactUs }) {
  return (
    <>
      <Modal show={showContactUs} onHide={closeContactUs} animation={true} centered>
        <Modal.Header closeButton>
          <Modal.Title>Contact Us</Modal.Title>
        </Modal.Header>
        <Modal.Body>
          <ContactForm />
        </Modal.Body>
      </Modal>
    </>
  );
}

function ContactForm() {
  return (
    <div id="contact">
      <div>
        <p>
          Email us at <a href="mailto:hello@lithic.tech">hello@lithic.tech</a> or use
          this form:
        </p>

        <Form
          as={"form"}
          method="POST"
          action={"/contact-success"}
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
              We'll never share your email with anyone else.
            </Form.Text>
          </Form.Group>
          <Form.Group>
            <Form.Label>Message</Form.Label>
            <Form.Control as="textarea" type="textarea" rows={3} />
          </Form.Group>
          <Button className={"mr-3 px-5"} variant="primary" type="submit">
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
