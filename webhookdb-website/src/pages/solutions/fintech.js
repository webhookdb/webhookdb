import "../../styles/custom.scss";

import CtaAction from "../../components/CtaAction";
import Lead from "../../components/Lead";
import { Link } from "gatsby";
import React from "react";
import Seo from "../../components/Seo";
import WavesHeaderCta from "../../components/WavesHeaderCta";
import WavesHeaderLayout from "../../components/WavesHeaderLayout";

export default function Fintech() {
  return (
    <WavesHeaderLayout
      header={
        <>
          <h1>WebhookDB for Fintech</h1>
          <Lead>
            WebhookDB is rocket fuel for fintech startups, providing a better way to
            integrate the 3rd party APIs that are fintech&rsquo;s lifeblood.
          </Lead>
          <WavesHeaderCta />
        </>
      }
    >
      <Seo title="Fintech" />
      <ul className="lead mb-5">
        <li>
          Get data change notifications through our amazing{" "}
          <Link to="/docs/webhooks">synchronous, reliable webhooks</Link>, rather than
          writing against the provider&rsquo;s webhook implementation, or polling
          yourself.
        </li>
        <li>
          Use SQL to query complex relationships rather than making slow and complex API
          requests.
        </li>
        <li>
          Depend on WebhookDB to eliminate complexity around integration of APIS like
          Plaid.
        </li>
      </ul>
      <CtaAction />
    </WavesHeaderLayout>
  );
}
