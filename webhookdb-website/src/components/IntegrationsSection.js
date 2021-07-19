import React from "react";
import { Container, Row, Col, Image } from "react-bootstrap";
import { Integrations } from "./Integrations";

export default function IntegrationsSection() {
  return (
    <Container className={"px-5 text-align-center mt-5"} fluid>
      <Row>
        <Col className={"text-md-center justify-content-center"}>
          <h1>Our Integrations.</h1>
          <p>
            We currently support integrations with Shopify (Customers and Orders),
            Twilio (SMS), and Stripe (Customers and Charges).
          </p>
        </Col>
      </Row>
      <Row className={"align-items-center "}>
        {Integrations.map((integration, idx) => {
          return (
            <Col key={idx} className={"mx-lg-5"}>
              <Image src={integration.logo} width={350} fluid />
            </Col>
          );
        })}
      </Row>
    </Container>
  );
}
