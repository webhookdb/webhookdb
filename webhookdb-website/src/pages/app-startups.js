import "../styles/custom.scss";

import CtaAction from "../components/CtaAction";
import Lead from "../components/Lead";
import { Link } from "gatsby";
import React from "react";
import Seo from "../components/Seo";
import WavesHeaderCta from "../components/WavesHeaderCta";
import WavesHeaderLayout from "../components/WavesHeaderLayout";

export default function AppStartups() {
  return (
    <WavesHeaderLayout
      header={
        <>
          <h1>WebhookDB for App Startups</h1>
          <Lead>
            WebhookDB frees developers and startup product managers to focus on your
            killer app&rsquo;s functionality and user experience, not the learning curve
            and idiosyncrasies of cloud integration &ldquo;middleware.&rdquo;
          </Lead>
          <WavesHeaderCta>Get Started with WebhookDB</WavesHeaderCta>
        </>
      }
    >
      <Seo title="App Startups" />
      <Lead className="mt-4">
        WebhookDB and its novel{" "}
        <Link to="/docs/new-paradigm">&ldquo;API-over-SQL&rdquo; approach</Link> will
        help you:
      </Lead>
      <ul className="lead mb-5">
        <li>Leapfrog your emerging category competitors with WebhookDB</li>
        <li>
          Massively reduce development complexity for composable applications built with
          multiple 3rd party APIs
        </li>
        <li>
          Accelerate time-to-creation by integrating all 3rd party API data flows into a
          secure PostgreSQL data reservoir
        </li>
        <li>Never worry about webhook data &ldquo;freshness&rdquo; again</li>
        <li>
          Avoid the cost, lock-in, and performance penalty associated with iPaaS and
          &ldquo;no code&rdquo; data connectivity platforms
        </li>
        <li>
          WebhookDB&rsquo;s developer-friendly, partner-advantaged engagement model
          enables affordable OEM pricing with support for product customization
        </li>
      </ul>
      <CtaAction />
    </WavesHeaderLayout>
  );
}
