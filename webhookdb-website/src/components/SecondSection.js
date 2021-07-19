import React from "react";
import { Container, Row, Col, Button } from "react-bootstrap";

export default function SecondSection() {
  return (
    <Container className={"p-5"} fluid>
      <Row>
        <Col className={"justify-content-center"} lg={6}>
          <h1>Our Guide.</h1>
          <p>
            The WebhookDB api is a developer tool designed to help you interface with
            your WebhookDB databases. Read our documentation for more information.
          </p>
          <br />
          <Button href={"/docs/home"} variant="outline-primary" size={"lg"}>
            Documentation
          </Button>
        </Col>
      </Row>
    </Container>
  );
}
