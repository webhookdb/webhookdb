import "../styles/custom.scss";

import { Button, Col, Container, Row } from "react-bootstrap";
import { IoIceCreamOutline, IoRadio, IoRocketOutline } from "react-icons/io5";
import { IoIosCode, IoMdStopwatch } from "react-icons/io";

import API2SQL from "../components/API2SQL";
import { BiHappyHeartEyes } from "react-icons/bi";
import Centered from "../components/Centered";
import CenteredDiv from "../components/CenteredDiv";
import Helmet from "react-helmet";
import Hilite from "../components/Hilite";
import LayoutPage from "../components/LayoutPage";
import Lead from "../components/Lead";
import { Link } from "gatsby";
import RLink from "../components/RLink";
import React from "react";
import { SafeExternalLink } from "../components/links";
import Seo from "../components/Seo";
import Waves from "../components/Waves";
import Webterm from "../components/Webterm";
import clsx from "clsx";
import integrations from "../modules/integrations";
import staticData from "../components/staticData";
import useContactUs from "../components/useContactUs";

export default function IndexPage() {
  const {
    render: renderContactUs,
    open: openContactUs,
    href: contactUsHref,
  } = useContactUs();
  return (
    <LayoutPage center>
      <Seo
        title=""
        meta={[
          {
            name: "keywords",
            content:
              "webhook, big data, analytics, api integration, database, data warehouse, api2sql, graphql, " +
              integrations.map(({ name }) => name).join(", "),
          },
        ]}
      />
      <Helmet>
        <title>WebhookDB</title>
      </Helmet>
      <Container className="bg-primary text-light pt-5 px-4" fluid>
        <Centered>
          <CenteredDiv>
            <h1 className="text-center">Postgres for API Integration</h1>
          </CenteredDiv>
          <Lead>
            Instantly sync, schematize, and normalize any 3rd or 1st party API into your
            own database.
          </Lead>
          <Lead>
            We&rsquo;ve leveraged PostgreSQL to solve API integration headaches,
            increase security, performance, and resiliency, and establish a single
            source of truth.
          </Lead>
          <CtaPair
            className="mb-5"
            leftProps={{
              href: "/docs/cli/",
              variant: "secondary",
              children: "Try WebhookDB for free",
            }}
            rightProps={{
              href: "/get-started",
              variant: "light",
              children: "Contact Us",
            }}
          ></CtaPair>
        </Centered>
      </Container>
      <Waves />
      <Container className="py-5 mt-3" fluid>
        <Centered>
          <Row>
            {features.map((f) => (
              <Feature key={f.title} {...f} />
            ))}
          </Row>
        </Centered>
      </Container>
      <Container className="bg-primary-light py-5" fluid>
        <Centered>
          <h2>Focus on your application, not your integrations.</h2>
          <Lead>
            WebhookDB&rsquo;s revolutionary{" "}
            <Link to="/docs/api2sql">{API2SQL} technology</Link> gives your development
            team API <Hilite>integration superpowers.</Hilite> Imagine all API data
            living free in your database, rather than locked behind a proprietary API.
          </Lead>
          <Lead>
            <strong>
              Instant access, always available, normalized and schematized.
            </strong>
          </Lead>
          <Lead>
            Take advantage of <Hilite>pre-built integrations</Hilite> for leading API
            providers, from Stripe to Twilio. Or write your own for{" "}
            <Hilite>literally any API</Hilite> in just a few minutes.
          </Lead>
          <Lead>
            <strong>
              WebhookDB cuts the Gordion knot of API integration. Forever.
            </strong>
          </Lead>
          <Lead>
            We call our new integration paradigm {API2SQL}. No more wasting key
            developer cycles on API integration, or staffing to deal with proprietary
            iPaaS frameworks, or expensive lock-in to cloud middleware.
          </Lead>
          <CtaPair
            className="mb-2"
            leftProps={{
              href: staticData.introVideo,
              variant: "secondary",
              as: SafeExternalLink,
              children: "Watch intro video",
            }}
            rightProps={{
              href: "/terminal",
              variant: "outline-secondary",
              children: "Try WebhookDB for free",
            }}
          ></CtaPair>
        </Centered>
      </Container>
      <Container className="px-4 my-5" fluid>
        <Centered>
          <h2>Our Guide.</h2>
          <Lead>
            As developers ourselves, we place a strong emphasis on clear documentation
            and intuitive, efficient tooling. We want you to be able to get up and going
            in minutes. Read our documentation for more information.
          </Lead>
          <CtaPair
            className="mb-2"
            leftProps={{
              href: "/docs/home",
              variant: "primary",
              children: "Documentation",
            }}
            rightProps={{
              href: "/docs/faq",
              variant: "outline-primary",
              children: "Read the FAQ",
            }}
          />
        </Centered>
      </Container>
      <Container className="px-4 py-5 bg-primary-light" fluid>
        <Centered>
          <h2>Try It.</h2>
          <Lead>
            We&rsquo;ve hosted the WebhookDB CLI as a Web Assembly binary you can run in
            your browser. This is a fully functional WebhookDB CLI, so you can get
            started here, and continue using it on your own machine.
          </Lead>
          <Lead>
            Use the terminal window below, or go to the{" "}
            <Link to="/terminal">dedicated terminal page</Link>.
          </Lead>
          <Webterm className="mb-2" loading="lazy" width="100%" height="300" />
        </Centered>
      </Container>
      <Container className="px-4 mt-5 mb-5" fluid>
        <Centered>
          <h2>Get In Touch.</h2>
          <Lead>
            We&rsquo;re an independent, bootstrapped team. So it&rsquo;s extra special
            when we hear from our customers.
          </Lead>
          <Button
            variant="primary"
            size="lg"
            className="cta mt-2 mb-3"
            href={contactUsHref}
            onClick={openContactUs}
          >
            Get in touch
          </Button>
        </Centered>
      </Container>
      {renderContactUs()}
    </LayoutPage>
  );
}

function CtaPair({ className, leftProps, rightProps, leftClass, rightClass }) {
  return (
    <Row className={clsx("justify-content-center", className)}>
      <Col xs="12" sm="auto">
        <Button
          size="lg"
          className={clsx("mt-3 w-100", leftClass)}
          style={{ minWidth: 300 }}
          as={RLink}
          {...leftProps}
        />
      </Col>
      <Col xs="12" sm="auto">
        <Button
          size="lg"
          className={clsx("mt-3 w-100", rightClass)}
          style={{ minWidth: 300 }}
          as={RLink}
          {...rightProps}
        />
      </Col>
    </Row>
  );
}

function Feature({ icon, title, text }) {
  const Icon = icon;
  return (
    <Col xs={12} sm={6} md={4} className="text-center">
      <div style={{ fontSize: "2.5rem" }} className="mb-2 text-primary">
        <Icon />
      </div>
      <h4>{title}</h4>
      <p>{text}</p>
    </Col>
  );
}

const features = [
  {
    icon: IoMdStopwatch,
    title: "Hours, not Weeks",
    text: (
      <>
        Integrate any API in hours, rather than days or weeks. There&rsquo;s nothing
        WebhookDB can&rsquo;t handle.
      </>
    ),
  },
  {
    icon: IoRocketOutline,
    title: "So Much Faster",
    text: (
      <>
        Data is instantly delivered to your backend. Query your database instead of a
        remote 3rd party server.
      </>
    ),
  },
  {
    icon: IoRadio,
    title: "Speak SQL",
    text: (
      <>
        No new frameworks to learn &mdash; speak the PostgreSQL you love, since API data
        is in your database.
      </>
    ),
  },
  {
    icon: IoIceCreamOutline,
    title: "Lowest Cost",
    text: (
      <>
        No account limits or usage based pricing. Designed to run easily and efficiently
        on your own infrastructure.
      </>
    ),
  },
  {
    icon: IoIosCode,
    title: "Integrate Any API",
    text: <>Choose from one of our pre-built replicators, or write your own.</>,
  },
  {
    icon: BiHappyHeartEyes,
    title: "Eliminate Complexity",
    text: (
      <>
        Patterns like <Link to="/docs/api2sql">{API2SQL}</Link> and{" "}
        <Link to="/docs/webhooks">Super Webhooks</Link> eliminate overall complexity.
      </>
    ),
  },
];
