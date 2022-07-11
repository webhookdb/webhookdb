import "../styles/custom.scss";

import API2SQL from "../components/API2SQL";
import CtaAction from "../components/CtaAction";
import Hilite from "../components/Hilite";
import Lead from "../components/Lead";
import { Link } from "gatsby";
import React from "react";
import Seo from "../components/Seo";
import WavesHeaderCta from "../components/WavesHeaderCta";
import WavesHeaderLayout from "../components/WavesHeaderLayout";

export default function DevelopmentAgencies() {
  return (
    <WavesHeaderLayout
      header={
        <>
          <h1>WebhookDB for Development Agencies</h1>
          <Lead>
            WebhookDB enables custom code developers to deliver demanding projects
            faster — at less cost – and with higher customer satisfaction than the
            current API application integration paradigm, whether iPaaS or No Code.
          </Lead>
          <WavesHeaderCta>Get Started with WebhookDB</WavesHeaderCta>
        </>
      }
    >
      <Seo title="Development Agencies" />
      <Lead className="mt-4">
        WebhookDB and its novel{" "}
        <Link to="/docs/api2sql">&ldquo;{API2SQL}&rdquo; approach</Link> will help you:
      </Lead>
      <ul className="lead mb-5">
        <li>Delight your most demanding customers with builder-friendly WebhookDB</li>
        <li>
          Happily <Hilite>check API integration off your to-do list</Hilite> with our
          developer friendly data flow reservoir approach to composable app creation
        </li>
        <li>
          <Hilite>Capitalize on the API-as-a-Product market land grab</Hilite> with
          WebhookDB supported integrations, automations, and best practices
        </li>
        <li>
          <Hilite>Differentiate your value proposition</Hilite> within your target
          customer use cases by offering 360 degree webhook visibility and SQL search
          and query
        </li>
        <li>
          <Hilite>Customize and co-brand/white-label</Hilite> WebhookDB for your
          geography or vertical market specialization
        </li>
      </ul>
      <CtaAction />
    </WavesHeaderLayout>
  );
}
