import "../../styles/custom.scss";

import API2SQL from "../../components/API2SQL";
import CtaAction from "../../components/CtaAction";
import Lead from "../../components/Lead";
import { Link } from "gatsby";
import React from "react";
import Seo from "../../components/Seo";
import WavesHeaderCta from "../../components/WavesHeaderCta";
import WavesHeaderLayout from "../../components/WavesHeaderLayout";

export default function DevelopmentAgencies() {
  return (
    <WavesHeaderLayout
      header={
        <>
          <h1>WebhookDB for Development Agencies</h1>
          <Lead>
            WebhookDB helps your agency to deliver demanding projects faster, at less
            cost, and with higher customer satisfaction than the current API application
            integration paradigm, whether inhouse, iPaaS or No Code.
          </Lead>
          <WavesHeaderCta />
        </>
      }
    >
      <Seo title="Development Agencies" />
      <Lead className="mt-4">
        WebhookDB and its novel{" "}
        <Link to="/docs/api2sql">&ldquo;{API2SQL}&rdquo; approach</Link> will help you:
      </Lead>
      <ul className="lead mb-5">
        <li>
          Massively reduce time spent on API integrations, whether it&rsquo;s a popular
          API or one no one has ever heard of.
        </li>
        <li>
          Differentiate your value proposition within your target customer use cases by
          offering 360 degree webhook visibility and SQL search and query.
        </li>
        <li>
          Customize and co-brand/white-label WebhookDB for your geography or vertical
          market specialization.
        </li>
      </ul>
      <CtaAction />
    </WavesHeaderLayout>
  );
}
