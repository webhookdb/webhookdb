import "../styles/custom.scss";

import CtaAction from "../components/CtaAction";
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
        <Link to="/docs/new-paradigm">&ldquo;API-over-SQL&rdquo; approach</Link> will
        help you:
      </Lead>
      <ul className="lead mb-5">
        <li>Delight your most demanding customers with builder-friendly WebhookDB</li>
        <li>
          Happily check API integration off your to-do list with our developer friendly
          data flow reservoir approach to composable app creation
        </li>
        <li>
          Capitalize on the API-as-a-Product market landgrab with WebhookDB supported
          integrations, automations, and best practices
        </li>
        <li>
          Differentiate your value proposition within your target customer use cases by
          offering 360 degree webhook visibility and SQL support
        </li>
        <li>
          Customize and co-brand/white-label WebhookDB for your geography or vertical
          market specialization
        </li>
      </ul>
      <CtaAction />
    </WavesHeaderLayout>
  );
}
