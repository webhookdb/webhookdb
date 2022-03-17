import "../styles/custom.scss";

import { Button, Col, Container, Image, Row } from "react-bootstrap";

import Helmet from "react-helmet";
import { Integrations } from "../components/Integrations";
import LayoutPage from "../components/LayoutPage";
import { Link } from "gatsby";
import React from "react";
import { SafeExternalLink } from "../components/links";
import Seo from "../components/Seo";
import Waves from "../components/Waves";
import Webterm from "../components/Webterm";
import WistiaEmbed from "../components/WistiaEmbed";
import staticData from "../components/staticData";
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
          <h2>Query any API, in real-time, with SQL.</h2>
          <p className="lead">
            WebhookDB mirrors data from 3rd party APIs into a dedicated Postgres
            database in realtime.
          </p>
          <p className="lead">
            Use this database connection in your applications and analytics systems.
          </p>
          <ul className="lead">
            <li>
              <span className="font-weight-bold">Fast</span>: Updates are immediate in
              most cases, or appear within a few seconds if the API requires polling for
              changes.
            </li>
            <li>
              <span className="font-weight-bold">Secure</span>: All your data lives in a
              dedicated database. Enterprise customers can self-host their data.
            </li>
            <li>
              <span className="font-weight-bold">Practical</span>: Get up and running in
              seconds for any supported API. Great unit testing setup too.
            </li>
            <li>
              <span className="font-weight-bold">Resilient</span>: Never worry about
              losing a webhook or out-of-order delivery. Use WebhookDB in applications
              as well as analytics.
            </li>
          </ul>
          <p>
            Mirroring data from 3rd party APIs so it can be quickly and easily queried
            in SQL is an <span className="font-weight-bold">extremely common need</span>
            .
          </p>
          <p>
            It&rsquo;s also undifferentiated.{" "}
            <span className="font-weight-bold">
              You shouldn&rsquo;t have to build this internally!
            </span>{" "}
            Use WebhookDB.
          </p>
          <Button href="/docs/home" variant="outline-light" size="lg" className="mt-2">
            Get Started
          </Button>
        </Centered>
      </Container>
      <Waves />
      <Container className="px-4 mt-5" fluid>
        <Centered>
          <h2>Why WebhookDB?</h2>
          <ul className="list-flush list-comfy">
            <li>
              Never have to figure out webhooks in an API again. Our CLI guides you
              through setting up webhooks interactively.
            </li>
            <li>Structured schema with important fields denormalized and indexed.</li>
            <li>
              Automatically backfill resources when you add an integration, and at any
              time afterwards.
            </li>
            <li>Never worry about failed and out-of-order webhook deliveries.</li>
            <li>
              Enterprise customers can provide their own database credentials to
              self-host data.
            </li>
            <li>
              Highly-available infrastructure so you don&rsquo;t need to worry about
              lost updates.
            </li>
            <li>
              You can proxy all webhooks through WebhookDB if you still want to see them
              yourself. No need for many verification routines or config secrets.
            </li>
            <li>
              WebhookDB is developer-focused, and entirely managed through an extremely
              friendly CLI.
            </li>
            <li>
              Automatic Foreign Data Wrappers so you can JOIN with WebhookDB tables, or
              import them into Materialized Views.
            </li>
            <li>
              If you love unit testing as much as we do, it&rsquo;s much easier to test
              code using WebhookDB than HTTP.
            </li>
            <li>
              <SafeExternalLink href={staticData.announcementBlog}>
                Learn why we built WebhookDB
              </SafeExternalLink>
              .
            </li>
          </ul>
          <div className="d-flex flex-column align-items-center pt-4 pb-3">
            <p>
              See it in action! And try it out{" "}
              <Link to="/terminal">right from your browser</Link>!
            </p>
            <div style={{ width: "80%" }}>
              <WistiaEmbed mediaUrl="https://fast.wistia.com/embed/medias/lrox7uw103" />
            </div>
          </div>
        </Centered>
      </Container>
      <Container className="px-4 mt-5" fluid>
        <Centered>
          <h2>Supported Integrations.</h2>
          <p>
            We currently support the following integrations, with more released every
            week. If you need a service or resource not listed below, please{" "}
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
                <Col key={idx} className="col-12 col-sm-6 col-md-4 col-lg-4">
                  <Image
                    src={integration.logo}
                    className="mb-3 img-fluid"
                    style={{ maxHeight: 80 }}
                  />
                  <div className="lead font-weight-bold mb-5">
                    {integration.resources.join(", ")}
                  </div>
                </Col>
              );
            })}
          </Row>
          <p>
            * Indicates coming soon. Please{" "}
            <a href="#" onClick={openContactUs}>
              Contact Us
            </a>{" "}
            if you need it immediately, or want any API not listed here.
          </p>
        </Centered>
      </Container>
      <Container className="px-4 mt-5" fluid>
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
      <Container className="px-4 mt-5" fluid>
        <Centered>
          <h2>Try It.</h2>
          <p>
            We&rsquo;ve hosted the WebhookDB CLI as a Web Assembly binary you can run in
            your browser. This is a fully functional WebhookDB CLI, so you can get
            started here, and continue using it on your own machine.
          </p>
          <p>
            Use the terminal window below, or go to the{" "}
            <Link to="/terminal">dedicated terminal page</Link>.
          </p>
          <Webterm loading="lazy" width="100%" height="500" />
        </Centered>
      </Container>
      <Container className="px-4 mt-5 mb-5" fluid>
        <Centered>
          <h2>Get In Touch.</h2>
          <p>
            We&rsquo;re an independent, bootstrapped team. So it&rsquo;s extra special
            when we hear from our customers. We&rsquo;d love for you to{" "}
            <a onClick={openContactUs} href="#">
              get in touch!
            </a>
          </p>
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
