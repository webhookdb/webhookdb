import "../../styles/custom.scss";

import API2SQL from "../../components/API2SQL";
import CtaAction from "../../components/CtaAction";
import Lead from "../../components/Lead";
import React from "react";
import Seo from "../../components/Seo";
import WavesHeaderCta from "../../components/WavesHeaderCta";
import WavesHeaderLayout from "../../components/WavesHeaderLayout";

export default function NoCode() {
  return (
    <WavesHeaderLayout
      header={
        <>
          <h1>WebhookDB for No-Code Apps</h1>
          <Lead>
            WebhookDB eliminates the dreaded complexity of 3rd party API integration in
            No-Code Apps by allowing integration against an SQL database rather than via
            API calls.
          </Lead>
          <WavesHeaderCta>Get Started with WebhookDB</WavesHeaderCta>
        </>
      }
    >
      <Seo title="No Code" />
      <ul className="lead mb-5">
        <li>
          Avoid the complexity of confusing API adapters and just query an SQL database
          instead.
        </li>
        <li>
          Easily query 3rd party APIs directly via {API2SQL} rather than copying data
          for the sake of reducing complexity.
        </li>
        <li>
          Get analytics &ldquo;for free&rdquo; by integrating all your existing
          WebhookDB API Data Reservoir with analytics tools and visualizations.
        </li>
      </ul>
      <CtaAction />
    </WavesHeaderLayout>
  );
}
