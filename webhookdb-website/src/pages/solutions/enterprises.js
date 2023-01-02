import "../../styles/custom.scss";

import API2SQL from "../../components/API2SQL";
import CtaAction from "../../components/CtaAction";
import Lead from "../../components/Lead";
import { Link } from "gatsby";
import React from "react";
import Seo from "../../components/Seo";
import WavesHeaderCta from "../../components/WavesHeaderCta";
import WavesHeaderLayout from "../../components/WavesHeaderLayout";

export default function Enterprises() {
  return (
    <WavesHeaderLayout
      header={
        <>
          <h1>WebhookDB for Enterprises</h1>
          <Lead>
            WebhookDB solves headaches for enterprises dealing with modernization and
            unification efforts of both external and internal services.
          </Lead>
          <WavesHeaderCta>Get Started with WebhookDB</WavesHeaderCta>
        </>
      }
    >
      <Seo title="Enterprises" />
      <Lead className="mt-4">
        WebhookDB and its novel{" "}
        <Link to="/docs/api2sql">&ldquo;{API2SQL}&rdquo; approach</Link> will help you:
      </Lead>
      <ul className="lead mb-5">
        <li>
          Unify data flows across modern and legacy stacks using industry-standard RDBMS
          that you&rsquo;re already familiar with.
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
        <li>Build custom integrations to tie together internal services.</li>
        <li>
          Enlist our <Link to="/licensing">elite professional services</Link> to help
          you design, plan, and execute on your internal initiatives.
        </li>
      </ul>
      <CtaAction />
    </WavesHeaderLayout>
  );
}
