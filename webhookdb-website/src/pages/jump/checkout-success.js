import JumpPageLayout from "../../components/JumpPageLayout";
import React from "react";
import Seo from "../../components/Seo";

export default function CheckoutSuccess() {
  return (
    <JumpPageLayout>
      <Seo title="Checkout Success" />
      <p>Thanks for supporting WebhookDB! We really appreciate it.</p>
      <p>
        Don&rsquo;t hesitate to reach out to{" "}
        <a href="mailto:hello@webhookdb.com">hello@webhookdb.com</a> with any feedback
        or support needs.
      </p>
      <p>You may close this page.</p>
    </JumpPageLayout>
  );
}
