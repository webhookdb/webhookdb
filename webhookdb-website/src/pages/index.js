import LayoutPage from "../components/LayoutPage";
import "../styles/custom.scss";
import Helmet from "react-helmet";
import Seo from "../components/Seo";
import React from "react";
import { Container, Row, Col, Button, Image } from "react-bootstrap";
import Waves from "../components/Waves";
import { Integrations } from "../components/Integrations";

export default function IndexPage() {
  return (
    <LayoutPage>
      <Seo
        title=""
        meta={[
          {
            name: "keywords",
            content:
              "web development, software, website, web app, monolith, microservices, ruby, rails, python, django, go, golang, stripe, twilio, shopify",
          },
        ]}
      />
      <Helmet>
        <title>WebhookDB</title>
      </Helmet>
      <Container className={"bg-primary text-light pt-5 px-5"} fluid>
        <Row>
          <Col className={"justify-content-center"} lg={6}>
            <h1>Webhook data as SQL.</h1>
            <p>
              Have you ever wanted to run an SQL query over your data in Stripe,
              Shopify, Twilio, or some other 3rd party service? The &ldquo;API
              Economy&rdquo; is great except when you actually need to work with data
              from 3rd party services in a tightly integrated way, like within an
              application or data pipeline.
            </p>
            <p>
              WebhookDB gives you a dedicated PostgreSQL database synced with data from
              3rd party services. We take care of issues like:
            </p>
            <ul>
              <li>
                Availability: We use a high-performance, highly available
                infrastructure, so you won&rsquo;t need to worry about lost updates.
              </li>
              <li>
                Synchronization: Never worry about out-of-order handling of webhooks.
              </li>
              <li>
                Backfilling: All our integrations support backfilling of resources, so
                once you set up WebhookDB to handle new webhooks you can easily backfill
                old data too.
              </li>
            </ul>
            <p>
              WebhookDB is developer-focused, and entirely managed through an extremely
              friendly CLI.
            </p>
            <Button
              href={"/docs/home"}
              variant="outline-light"
              size={"lg"}
              className="mt-2"
            >
              Get Started
            </Button>
          </Col>
        </Row>
      </Container>
      <Waves />
      <Container className={"px-5 mt-5"} fluid>
        <h1>Supported Integrations.</h1>
        <p>
          We currently support the following integrations. If you need a service or
          resource not listed below, please Contact Us. Adding new integrations for most
          services is pretty simple and we should be able to add what you need within
          two days.
        </p>
        <Row className={"justify-content-start align-items-start mt-5"}>
          {Integrations.map((integration, idx) => {
            return (
              <Col key={idx} md="auto" sm="auto" xs="auto" className={"mb-3 mr-4"}>
                <Image
                  src={integration.logo}
                  className="mb-3"
                  style={{ maxHeight: 80 }}
                />
                <ul className="list-unstyled">
                  {integration.resources.map((r) => (
                    <li key={r} className="font-weight-bolder lead">
                      {r}
                    </li>
                  ))}
                </ul>
              </Col>
            );
          })}
        </Row>
      </Container>
      <Container className={"px-5 mt-5 mb-5"} fluid>
        <Row>
          <Col className={"justify-content-center"} lg={6}>
            <h1>Our Guide.</h1>
            <p>
              As developers ourselves, we place a strong emphasis on clear documentation
              and intuitive, efficient tooling. Get up and going in minutes. Read our
              documentation for more information.
            </p>
            <Button
              href={"/docs/home"}
              variant="outline-primary"
              size={"lg"}
              className="mt-2"
            >
              Documentation
            </Button>
          </Col>
        </Row>
      </Container>
    </LayoutPage>
  );
}
