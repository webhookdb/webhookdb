import "../../styles/custom.scss";

import API2SQL from "../../components/API2SQL";
import CtaAction from "../../components/CtaAction";
import Lead from "../../components/Lead";
import { Link } from "gatsby";
import React from "react";
import Seo from "../../components/Seo";
import WavesHeaderCta from "../../components/WavesHeaderCta";
import WavesHeaderLayout from "../../components/WavesHeaderLayout";

export default function AppStartups() {
  return (
    <WavesHeaderLayout
      header={
        <>
          <h1>WebhookDB for App Startups</h1>
          <Lead>
            WebhookDB frees developers and startup product managers to focus on your
            killer app&rsquo;s functionality and user experience, not the learning curve
            and idiosyncrasies of API integration.
          </Lead>
          <WavesHeaderCta />
        </>
      }
    >
      <Seo title="App Startups" />
      <Lead className="mt-4">
        WebhookDB and its novel{" "}
        <Link to="/docs/api2sql">&ldquo;{API2SQL}&rdquo; approach</Link> will help you:
      </Lead>
      <ul className="lead mb-5">
        <li>
          Massively reduce development complexity by integrating 3rd party APIs via SQL
          rather than custom REST or GraphQL clients.
        </li>
        <li>
          Get data change notifications through our amazing{" "}
          <Link to="/docs/webhooks">synchronous, reliable webhooks</Link>, rather than
          writing against the provider&rsquo;s webhook implementation, or polling
          yourself.
        </li>
        <li>
          Avoid the cost, lock-in, and performance penalty associated with iPaaS and
          &ldquo;no code&rdquo; data connectivity platforms.
        </li>
        <li>
          WebhookDB&rsquo;s developer-friendly, partner-advantaged engagement model
          enables affordable pricing with support for product customization.
        </li>
      </ul>
      <CtaAction />
    </WavesHeaderLayout>
  );
}
