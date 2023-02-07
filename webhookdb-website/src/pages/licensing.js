import "../styles/custom.scss";

import API2SQL from "../components/API2SQL";
import ContactForm from "../components/ContactForm";
import Hilite from "../components/Hilite";
import Lead from "../components/Lead";
import { Link } from "gatsby";
import React from "react";
import Seo from "../components/Seo";
import WavesHeaderLayout from "../components/WavesHeaderLayout";

export default function Licensing() {
  const [contactState, setContactState] = React.useState(null);
  return (
    <WavesHeaderLayout
      header={
        <>
          <h1>Licensing and Partnering</h1>
          <Lead>
            Everything about WebhookDB, including its features, technical design,
            pricing, licensing, and support, is built to help teams execute better,
            faster, and more reliably.
          </Lead>
        </>
      }
    >
      <Seo title="Licensing and Partnering" />
      <Lead className="mt-4">
        We think of our customers in <Hilite>two broad camps.</Hilite>
      </Lead>
      <Lead>
        In the first camp are <Hilite>early startups and entrepreneurs,</Hilite> who
        need to do a whole lot with very little, and have minimal budgets or appetite
        for contracts. But they are willing to take {API2SQL} for a ride and see how it
        solves their problems.
      </Lead>
      <Lead>
        For these folks, we offer WebhookDB entirely for free. That means unlimited
        integrations, and unlimited storage per-integration. While this may change in
        the future, the fact is that WebhookDB is so reliable and efficient to operate,
        that we what we spend on these customers, we get back in <em>vibes</em>.
      </Lead>
      <Lead>
        In the second camp are the{" "}
        <Hilite>customers who are looking for another level of value,</Hilite> and are
        willing and able to spend some money to get it. All of these customers have some
        nontrivial needs around integration of 3rd or 1st party APIs, like reliable
        webhooks, single sources of truth, real-time analytics, and integration with
        non-standard or non-public APIs that integration platforms don&rsquo;t support.
      </Lead>
      <Lead>
        These customers understand how {API2SQL}, and other features like{" "}
        <Link to="/docs/webhooks">
          synchronous reliable &ldquo;super&rdquo; webhooks
        </Link>
        , solve their integration headaches. And because those headaches are so
        significant, they&rsquo;re happy to pay us to make them go away.
      </Lead>
      <Lead>
        We generally work closely with these customers. For one, we bring to bear our
        consulting and freelance development experience from{" "}
        <a href="https://lithic.tech">Lithic Technology</a>. This means WebhookDB
        <Hilite>
          professional services are absolutely best-in-class, not an afterthought.
        </Hilite>
      </Lead>
      <Lead>
        Second, we work with you to{" "}
        <Hilite>figure out a licensing structure that works for your needs;</Hilite>{" "}
        most commonly, this is a yearly license with a conversion into a
        &ldquo;source&rdquo; license, so you don&rsquo;t need to worry about paying for
        WebhookDB in perpetuity or losing access if we go out of business. You get all
        the benefits you&rsquo;d have if you had built it yourself.
      </Lead>
      <Lead>
        These usually include a significant amount of custom integration development
        &mdash; in fact, most of our WebhookDB integrations have been developed in a
        custom capacity.
      </Lead>
      <Lead>
        If you&rsquo;re interested in taking WebhookDB for a spin using our publicly
        available integrations, head on over to the <Link to="/terminal">terminal</Link>{" "}
        and <Hilite>get started from your browser.</Hilite> You can easily change your
        license later.
      </Lead>
      <Lead>
        To discuss licensing WebhookDB, or anything else, please use this contact form,
        or email <a href="mailto:hello@webhookdb.com">hello@webhookdb.com</a>.
      </Lead>
      <ContactForm
        state={contactState}
        setState={setContactState}
        hideEmail
        className="max-width-sm"
      />
    </WavesHeaderLayout>
  );
}
