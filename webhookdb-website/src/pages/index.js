import "../styles/custom.scss";

import { Button, Container, Image } from "react-bootstrap";

import API2SQL from "../components/API2SQL";
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
            WebhookDB accelerates application development and performance by extending
            your existing database with
            <Hilite>{API2SQL} data integration superpowers</Hilite>.
          </Lead>
          <Lead>
            WebhookDB syncs, ingests, schematizes, and automates data from 3rd party
            APIs in realtime, enabling a <Hilite>single source of truth</Hilite> for
            your application builders and product managers.
          </Lead>
          <Lead>
            <Hilite>Replicate and query any API, in real-time, with SQL</Hilite>, right
            from your <Hilite>existing database</Hilite>, and see how{" "}
            <Hilite>fast and simple</Hilite>
            integration with external APIs becomes.
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
          <h2 className="mt-2">{API2SQL} Spells NO Cloud Middleware</h2>
          <Lead>
            WebhookDB acts like a database extension that takes 3rd party API data and
            syncs it right into your database &mdash; you&rsquo;ll have{" "}
            <Hilite>fresh API data in heart of your application backend</Hilite>.
            Instant access, always available, normalized and schematized.
          </Lead>
          <Lead>
            We call our new integration paradigm {API2SQL}. No more wasting key
            developer cycles on API integration, or staffing to deal with proprietary
            iPaaS frameworks, or expensive lock-in to cloud middleware.
          </Lead>
          <Lead></Lead>
          <Lead>
            WebhookDB cuts the Gordion knot of API integration.{" "}
            <stroneg>Forever.</stroneg>
          </Lead>
          <Lead>
            With {API2SQL}, application developers access 3rd party API data using the same database
            they use for application data. This unified application
            data reservoir approach <Hilite>simplifies development</Hilite>, and enables
            product teams to
            <Hilite>focus on your core value proposition</Hilite>, not 3rd party API
            integration.
          </Lead>
          <Lead>
            See it in action! Or try it out{" "}
            <Link to="/terminal">right from your browser</Link>!
          </Lead>
          <CenteredDiv>
            <div style={{ width: "80%" }}>
              <WistiaEmbed mediaUrl="https://fast.wistia.com/embed/medias/lrox7uw103" />
            </div>
          </CenteredDiv>
          <h2 className="mt-5">Unbeatable Partnering & Pricing</h2>
          <Lead>
            We know that a paradigm shift from REST or GraphQL is no simple thing.
            That&rsquo;s why WebhookDB&rsquo;s {API2SQL} reservoir-based integration
            approach comes equipped with a <Hilite>partner-first business model</Hilite>
            .
          </Lead>
          <Lead>
            Take advantage of our pre-built integrations for leading API providers, from
            Stripe to Twilio. Most of our partners have us build custom integrations &mdash; we can tackle
            literally any API, 1st or 3rd party.
          </Lead>
          <Lead>
            License WebhookDB as a fully-hosted SaaS, or for self-hosting, or with a
            source license for unlimited development.
          </Lead>
          <Lead>
            We&rsquo;re not trying to build the next integration-as-a-service hub to
            compete with our customers and partners. Instead, we&rsquo;ve built a{" "}
            <Hilite>next-generation integration capability</Hilite> to empower our
            partners. It turns out most API integration is a commodity problem;
            WebhookDB solves it for you so you can move on to more important things.
          </Lead>
          <h2 className="mt-5">{API2SQL} Is Better</h2>
          <Lead>
            {API2SQL} offers a new, superior paradigm for API integration, replacing
            legacy patterns like REST, GraphSQL, and WSDL.
          </Lead>
          <Lead>What makes {API2SQL} superior?</Lead>
          <ul className="lead">
            <li>
              <span className="font-weight-bold">Fast</span>: Query a local database
              instead of a remote 3rd party server.
            </li>
            <li>
              <span className="font-weight-bold">Flexible</span>: Use standard SQL tools
              to inspect schemas, select and filter data, and anything else you can do
              with SQL.
            </li>
            <li>
              <span className="font-weight-bold">Practical</span>: Integration is a
              breeze. Get up and running in seconds for any supported API. Unit testing
              is a lot more fun than using HTTP.
            </li>
            <li>
              <span className="font-weight-bold">Secure</span>: Use standard SQL-based
              access controls for different parts of your system, rather than
              rudimentary access control most APIs offer.
            </li>
          </ul>
          <Button
            href="/docs/api2sql"
            variant="outline-primary"
            size="lg"
            className="cta"
            as={RLink}
          >
            Learn more about {API2SQL}
          </Button>
          <h2 className="mt-5">API Data Reservoir</h2>
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
          <Lead>
            Learn more about <Link to="/docs/api2sql">{API2SQL}</Link> and the{" "}
            <Link to="/docs/api-reservoir">API Data Reservoir</Link>.
          </Lead>
          <CenteredDiv>
            <Link to="/docs/api-reservoir">
              <Image
                src={Reservoir}
                fluid
                height={200}
                style={{ maxHeight: 300, marginTop: "1rem" }}
              />
            </Link>
          </CenteredDiv>
        </Centered>
      </Container>
      <Container className="px-4 mt-5" fluid>
        <Centered>
          <h2>Our Guide.</h2>
          <Lead>
            As developers ourselves, we place a strong emphasis on clear documentation
            and intuitive, efficient tooling. We want you to be able to get up and going in minutes. Read our
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
