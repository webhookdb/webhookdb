import "../../styles/custom.scss";

import API2SQL from "../../components/API2SQL";
import CtaAction from "../../components/CtaAction";
import Lead from "../../components/Lead";
import { Link } from "gatsby";
import React from "react";
import Seo from "../../components/Seo";
import WavesHeaderCta from "../../components/WavesHeaderCta";
import WavesHeaderLayout from "../../components/WavesHeaderLayout";

export default function DigitalTransformation() {
  return (
    <WavesHeaderLayout
      header={
        <>
          <h1>WebhookDB for Digital Transformation</h1>
          <Lead>
            WebhookDB empowers digital transformation consultancies and digital-first
            agencies to seamlessly unify and embed API data flows within external and
            internal applications.
          </Lead>
          <WavesHeaderCta />
        </>
      }
    >
      <Seo title="Digital Transformation" />
      <Lead className="mt-4">
        WebhookDB and its novel{" "}
        <Link to="/docs/api2sql">&ldquo;{API2SQL}&rdquo; approach</Link> will help you:
      </Lead>
      <ul className="lead mb-5">
        <li>
          Unify data flows across modern and legacy stacks using industry-standard RDBMS
          that your clients are already familiar with.
        </li>
        <li>
          Support best-in-class intergration patterns between APIs, using SQL and{" "}
          <Link to="/docs/webhooks">
            synchronous, reliable &ldquo;super&rdquo; webhooks
          </Link>
          , rather than hard-to-coordinate REST or GraphQL wrappers.
        </li>
        <li>
          Align with the fast emerging <strong>MACH</strong>
          (microservices, API-first, composable, headless) partner ecosystem.
        </li>
        <li>
          Capitalize on WebhookDB product integrations across the API economy so you
          don&rsquo;t need to write them yourself.
        </li>
        <li>Develop partner-specific integrations for internal services.</li>
        <li>
          Private-label and customize WebhookDB as a core capability within your
          transformation services portfolio.
        </li>
      </ul>
      <CtaAction />
    </WavesHeaderLayout>
  );
}
