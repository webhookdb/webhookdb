import "../styles/custom.scss";

import { Button, Container, Image } from "react-bootstrap";

import Centered from "../components/Centered";
import CenteredDiv from "../components/CenteredDiv";
import Helmet from "react-helmet";
import Hilite from "../components/Hilite";
import LayoutPage from "../components/LayoutPage";
import Lead from "../components/Lead";
import { Link } from "gatsby";
import RLink from "../components/RLink";
import React from "react";
import Reservoir from "../images/diagram-api2sql-reservoir.png";
import { SafeExternalLink } from "../components/links";
import Seo from "../components/Seo";
import Waves from "../components/Waves";
import Webterm from "../components/Webterm";
import WistiaEmbed from "../components/WistiaEmbed";
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
              "webhook, big data, analytics, stripe, shopify, integration, database, data warehouse, data",
          },
        ]}
      />
      <Helmet>
        <title>WebhookDB</title>
      </Helmet>
      <Container className="bg-primary text-light pt-5 px-4" fluid>
        <Centered>
          <CenteredDiv>
            <h1>Unify. Automate. Build.</h1>
          </CenteredDiv>
          <Lead>
            WebhookDB is your <Hilite>Unified API Data Reservoir</Hilite> for the age of{" "}
            <Hilite>Composable Applications Development.</Hilite>
          </Lead>
          <Lead>
            WebhookDB mirrors data from 3rd party APIs into a dedicated Postgres
            database in realtime. You get the connection string.{" "}
            <Hilite>Query any API, in real-time, with SQL.</Hilite>
          </Lead>
          <Lead>
            Use this database connection in your applications and analytics systems.
          </Lead>
          <CenteredDiv className="mb-3">
            <Button
              href="/get-started"
              variant="light"
              size="lg"
              className="mt-2 cta"
              as={RLink}
            >
              Get Started
            </Button>
          </CenteredDiv>
        </Centered>
      </Container>
      <Waves />
      <Container className="px-4" fluid>
        <Centered>
          <h2 className="mt-2">The API Data Reservoir</h2>
          <Lead>
            Reservoirs are designed to collect drainage over large area and turn it into{" "}
            <Hilite>clean, safe, and predictable</Hilite> water servicing various
            activities downstream.
          </Lead>
          <Lead>
            WebhookDB is designed the same way: we <Hilite>collect and process</Hilite>{" "}
            data from external APIs and make it{" "}
            <Hilite>structured, relational, and accessible</Hilite> for use in your
            applications and analytics.
          </Lead>
          <CenteredDiv>
            <Image src={Reservoir} fluid height={300} style={{ maxHeight: 400 }} />
          </CenteredDiv>
          <h2 className="mt-5">Introducing API-over-SQL</h2>
          <Lead>
            Move over JSON-over-HTTP, REST, gRPC, and WSDL. Say hello to API-over-SQL,
            which we believe offers a new, superior paradigm for API integration.
          </Lead>
          <Button
            href="/docs/new-paradigm"
            variant="outline-primary"
            size="lg"
            className="cta mb-4"
            as={RLink}
          >
            Learn more about API-over-SQL
          </Button>
          <Lead>What makes API-over-SQL superior?</Lead>
          <ul className="lead">
            <li>
              <span className="font-weight-bold">Fast</span>: Query a database instead
              of a remote 3rd party server.
            </li>
            <li>
              <span className="font-weight-bold">Flexible</span>: Use standard SQL tools
              to inspect schemas, select and filter data, and anything else you can do
              with SQL.
            </li>
            <li>
              <span className="font-weight-bold">Practical</span>: Integration is a
              breeze. Get up and running in seconds for any supported API. Unit testing
              is a lot more fun than with JSON-over-HTTP.
            </li>
            <li>
              <span className="font-weight-bold">Secure</span>: Use standard SQL-based
              access controls for different parts of your system, rather than the more
              rudimentary version an API offers.
            </li>
          </ul>
          <Lead>
            See it in action! And try it out{" "}
            <Link to="/terminal">right from your browser</Link>!
          </Lead>
          <CenteredDiv>
            <div style={{ width: "80%" }}>
              <WistiaEmbed mediaUrl="https://fast.wistia.com/embed/medias/lrox7uw103" />
            </div>
          </CenteredDiv>
        </Centered>
      </Container>
      <Container className="px-4 mt-5" fluid>
        <Centered>
          <h2>Our Guide.</h2>
          <Lead>
            As developers ourselves, we place a strong emphasis on clear documentation
            and intuitive, efficient tooling. Get up and going in minutes. Read our
            documentation for more information.
          </Lead>
          <Lead>
            <SafeExternalLink href={staticData.announcementBlog}>
              Learn why we built WebhookDB
            </SafeExternalLink>
            .
          </Lead>
          <Button
            href="/docs/home"
            variant="outline-primary"
            size="lg"
            className="cta mt-2"
            as={RLink}
          >
            Documentation
          </Button>
        </Centered>
      </Container>
      <Container className="px-4 mt-5" fluid>
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
          <Webterm loading="lazy" width="100%" height="500" />
        </Centered>
      </Container>
      <Container className="px-4 mt-5 mb-5" fluid>
        <Centered>
          <h2>Get In Touch.</h2>
          <Lead>
            We&rsquo;re an independent, bootstrapped team. So it&rsquo;s extra special
            when we hear from our customers. We&rsquo;d love for you to{" "}
            <a onClick={openContactUs} href={contactUsHref}>
              get in touch!
            </a>
          </Lead>
        </Centered>
      </Container>
      {renderContactUs()}
    </LayoutPage>
  );
}
