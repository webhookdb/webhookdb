import "../../styles/custom.scss";

import API2SQL from "../../components/API2SQL";
import CtaAction from "../../components/CtaAction";
import Hilite from "../../components/Hilite";
import Lead from "../../components/Lead";
import { Link } from "gatsby";
import React from "react";
import Seo from "../../components/Seo";
import WavesHeaderCta from "../../components/WavesHeaderCta";
import WavesHeaderLayout from "../../components/WavesHeaderLayout";

export default function Analytics() {
  return (
    <WavesHeaderLayout
      header={
        <>
          <h1>WebhookDB for Analytics</h1>
          <Lead>
            WebhookDB provides{" "}
            <Hilite>affordable, real-time, turnkey integration</Hilite> with popular,
            and not-so-popular, 3rd party APIs.
          </Lead>
          <WavesHeaderCta>Get Started with WebhookDB</WavesHeaderCta>
        </>
      }
    >
      <Seo title="Analytics" />
      <Lead className="mt-4">
        WebhookDB and its novel <Link to="/docs/api2sql">{API2SQL} approach</Link> will
        help you:
      </Lead>
      <ul className="lead mb-5">
        <li>
          <Hilite>Avoid the extremely high cost</Hilite> of all other data integration
          platforms, like Hevo or Fivetran.
        </li>
        <li>
          Integrate <Hilite>any API</Hilite> with zero or minimal effort, including
          unpopular or poorly-designed ones.
        </li>
        <li>
          <Hilite>Bring your own visualization tools</Hilite>, like Metabase, Redash, or
          Tableau.
        </li>
        <li>
          Get <Hilite>real-time, normalized, schematized data</Hilite>, not just
          unstructured JSON.
        </li>
        <li>
          Write performant complex queries{" "}
          <Hilite>with or without a data warehouse</Hilite>.
        </li>
      </ul>
      <CtaAction />
    </WavesHeaderLayout>
  );
}
