import React from "react";
import { Button, Container, Row, Col } from "react-bootstrap";
import "../styles/custom.scss";
import Waves from "./Waves";

export default function FirstSection() {
  return (
    <>
      <Container className={"bg-primary text-light p-5"} fluid>
        <Row>
          <Col className={"justify-content-center"} lg={6}>
            <h1>Our Product.</h1>
            <p>
              When your code depends on information from external services, it can be
              hard to account for having to interface with an API that is outside of
              your control. We're so excited to launch our product, WebhookDB, in an
              effort to solve that problem. WebhookDB is a service that intercepts and
              archives webhooks from heavily-used external APIs into a queryable SQL
              database that can be accessed at any time through our lightweight CLI.
            </p>
            <br />
            <Button href={"/docs/home"} variant="outline-light" size={"lg"}>
              Get Started
            </Button>
          </Col>
        </Row>
      </Container>
      <Waves />
      {/*<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1440 320">*/}
      {/*  <path*/}
      {/*    fill="#0099ff"*/}
      {/*    d="M0,160L60,138.7C120,117,240,75,360,74.7C480,75,600,117,720,117.3C840,117,960,75,1080,58.7C1200,43,1320,53,1380,58.7L1440,64L1440,0L1380,0C1320,0,1200,0,1080,0C960,0,840,0,720,0C600,0,480,0,360,0C240,0,120,0,60,0L0,0Z"*/}
      {/*  />*/}
      {/*</svg>*/}
    </>
  );
}
