import "../styles/custom.scss";

import { Button, Col, Container, Image, Row } from "react-bootstrap";

import Helmet from "react-helmet";
import { Integrations } from "../components/Integrations";
import LayoutPage from "../components/LayoutPage";
import React from "react";
import Seo from "../components/Seo";
import Waves from "../components/Waves";
import useContactUs from "../components/useContactUs";

export default function IndexPage() {
  const { render: renderContactUs, open: openContactUs } = useContactUs();
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
      <Container className="bg-primary text-light pt-5 px-4" fluid>
        <Row>
          <Col className="justify-content-center" lg={6}>
            <h2>Webhook data as SQL.</h2>
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
              href="/docs/home"
              variant="outline-light"
              size="lg"
              className="mt-2"
            >
              Get Started
            </Button>
          </Col>
        </Row>
      </Container>
      <Waves />
      <Container className="px-4 mt-5" fluid>
        <h2>Supported Integrations.</h2>
        <p>
          We currently support the following integrations. If you need a service or
          resource not listed below, please{" "}
          <a href="#" onClick={openContactUs}>
            Contact Us
          </a>
          . Adding new integrations for most services is pretty simple and we should be
          able to add what you need within two days.
        </p>
        <Row className="justify-content-sm-center justify-content-xs-start  align-items-start mt-5">
          {Integrations.map((integration, idx) => {
            return (
              <Col key={idx} className="col-xl-3 col-sm-6 col-12 text-sm-center">
                <Image
                  src={integration.logo}
                  className="mb-1 img-fluid"
                  style={{ maxHeight: 80 }}
                />
                <ul className="list-unstyled mb-5">
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
      <Container className="px-4 mt-5 mb-5" fluid>
        <Row>
          <Col className="justify-content-center" lg={6}>
            <h2>Our Guide.</h2>
            <p>
              As developers ourselves, we place a strong emphasis on clear documentation
              and intuitive, efficient tooling. Get up and going in minutes. Read our
              documentation for more information.
            </p>
            <Button
              href="/docs/home"
              variant="outline-primary"
              size="lg"
              className="mt-2"
            >
              Documentation
            </Button>
          </Col>
        </Row>
      </Container>
      {renderContactUs()}
    </LayoutPage>
  );
}
