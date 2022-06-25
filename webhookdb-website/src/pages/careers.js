import "../styles/custom.scss";

import Lead from "../components/Lead";
import React from "react";
import { SafeExternalLink } from "../components/links";
import Seo from "../components/Seo";
import WavesHeaderLayout from "../components/WavesHeaderLayout";

export default function Careers() {
  return (
    <WavesHeaderLayout
      header={
        <>
          <h1>Careers</h1>
          <Lead>
            WebhookDB is brought to you by the good folks at{" "}
            <SafeExternalLink href="https://lithic.tech" className="alt-link">
              Lithic Technology
            </SafeExternalLink>
            . We&rsquo;re currently hiring backend engineers for WebhookDB, with
            experience in Go and/or Ruby (not Rails), and ideally with experience in
            Postgres, and distributed systems.
          </Lead>
          <Lead>
            If you&rsquo;re interested in working with us, please shoot over an email to{" "}
            <a href="mailto:jobs@lithic.tech" className="alt-link">
              jobs@lithic.tech
            </a>{" "}
            with a CV and short blurb about who you are and why WebhookDB is interesting
            to you, and we&rsquo;ll get back to you.
          </Lead>
        </>
      }
    >
      <Seo title="Careers" />
    </WavesHeaderLayout>
  );
}
