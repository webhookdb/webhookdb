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
    <LayoutPage center>
      <Seo
        title=""
        meta={[
          {
            name: "keywords",
            content:
              "webhook, big data, analytics, stripe, shopify, integration, database, data warehouse, data",
          },
        ]}
      />
      <Helmet>
        <title>WebhookDB</title>
      </Helmet>
      <Container className="bg-primary text-light pt-5 px-4" fluid>
        <Centered>
          <h2>
            Your 3<sup>rd</sup> Party Data in SQL.
          </h2>
          <p>
            Querying a database with SQL is easy. SQL databases are among the most
            well-supported and ubiquitous technologies around.
          </p>
          <p>APIs are great, but not nearly as seamless to use.</p>
          <p>
            What if you could query data from 3rd party services as easily as your own
            application data?
          </p>
          <p className="lead">Enter WebhookDB.</p>
          <p>
            WebhookDB solves a simple problem, and it solves it very well. We store data
            from the APIs you use in a database, and gives you an Postgres connection
            string, so you can query it from both your applications, and your analytics
            systems.
          </p>
          <p>
            <em>
              That&rsquo;s right, we built WebhookDB to be used in applications, not
              just analytics.
            </em>
          </p>
          <p>
            You may have built something similar &mdash; we definitely had many times
            before building WebhookDB. We save you the undifferentiated work of turning
            3rd party data into ergonomic SQL tables.
          </p>
          <Button href="/docs/home" variant="outline-light" size="lg" className="mt-2">
            Get Started
          </Button>
        </Centered>
      </Container>
      <Waves />
      <Container className="px-4 mt-5" fluid>
        <Centered>
          <h2>Features.</h2>
          <ul className="list-flush list-comfy">
            <li>
              Connection to your own isolated Postgres database containing your data.
            </li>
            <li>
              Highly-available infrastructure so you don&rsquo;t need to worry about
              lost updates.
            </li>
            <li>
              Synchronization to handle out-of-order webhook updates, without having to
              re-query the service.
            </li>
            <li>
              Backfilling of resources created before you set up your integration.
            </li>
            <li>
              WebhookDB is developer-focused, and entirely managed through an extremely
              friendly CLI.
            </li>
          </ul>
        </Centered>
      </Container>
      <Container className="px-4 mt-5" fluid>
        <Centered>
          <h2>Supported Integrations.</h2>
          <p>
            We currently support the following integrations. If you need a service or
            resource not listed below, please{" "}
            <a href="#" onClick={openContactUs}>
              Contact Us
            </a>
            .
          </p>
          <p>
            Adding new integrations for most services is pretty simple and we should be
            able to add what you need within two days.
          </p>
          <Row className="justify-content-sm-center justify-content-xs-start align-items-start mt-5">
            {Integrations.map((integration, idx) => {
              return (
                <Col key={idx} className="col-12 col-sm-6  col-md-4 col-lg-4">
                  <Image
                    src={integration.logo}
                    className="mb-3 img-fluid"
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
          <p>
            * Indicates coming soon (before end of 2021). Please{" "}
            <a href="#" onClick={openContactUs}>
              Contact Us
            </a>{" "}
            if you would like it earlier.
          </p>
        </Centered>
      </Container>
      <Container className="px-4 mt-5 mb-5" fluid>
        <Centered>
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
        </Centered>
      </Container>
      {renderContactUs()}
    </LayoutPage>
  );
}

function Centered({ children }) {
  return (
    <Row className="justify-content-center">
      <Col md={12} lg={8} xl={6}>
        {children}
      </Col>
    </Row>
  );
}
