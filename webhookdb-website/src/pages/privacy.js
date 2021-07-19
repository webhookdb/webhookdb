import ContentPageLayout from "../components/ContentPageLayout";
import { LegalContactText } from "../components/legal";
import React from "react";
import Seo from "../components/Seo";

/* eslint-disable react/no-unescaped-entities */
export default function Privacy() {
  return (
    <ContentPageLayout>
      <Seo title="Privacy Policies" />
      <h1 className="text-center">Privacy Policy</h1>
      <p>
        Here’s the short of it: we keep your data as safe as we can, store and track as
        little as we must, and share with 3rd parties only what is necessary. We do not,
        and will absolutely never, sell or share your information with advertisers. We
        will, to the best of our ability, ensure that we only use 3rd parties who also
        make this commitment.
      </p>
      <p>
        The rest of this document is the long of it. When this document uses "we", it
        means Lithic Technology LLC, the creators and operators of WebhookDB (this
        website and application).
      </p>
      <p>
        By visiting this website or using the WebhookDB Command Line Interface, you are
        accepting the terms of this Privacy Policy.
      </p>

      <h3>Information We Gather or Receive</h3>
      <p>
        When you register your account, you share with us your email and potentially
        other information, such as your name, as well as the name and billing email of
        organizations you add to WebhookDB.
      </p>
      <p>
        When you add an integration to a service, we collect the webhook data that
        service sends to us. This information is stored only in a Postgres database
        specifically for the organization that set up the integration. The information
        we receive from webhooks is never shared with any 3rd parties.
      </p>
      <p>
        When you instruct WebhookDB to backfill information from a service, you must
        provide it with some sort of credentials that allow it to query the service. We
        will only use the credentials for backfilling, and never make any other requests
        with those credentials. Many services allow you to restrict the scope of
        credentials, and the tool will let you know what scopes are required for
        services that support this.
      </p>
      <p>
        If you want to remove WebhookDB's access to any service, you should remove the
        service integration through the CLI. We will remove the credentials from our
        database. You should also revoke any credentials you shared with WebhookDB, and
        remove it as a webhook target in the service.
      </p>
      <p>
        We will not sell or disclose your name, email address or other personal
        information to third parties without your explicit consent, except as specified
        in this policy.
      </p>
      <h3>Controlling Your Information</h3>
      <p>
        When you remove a service integration, WebhookDB deletes any credentials
        associated with that service. Without those credentials, we cannot issue any API
        requests to that service on your behalf, and usually cannot verify any webhooks
        we get from that service, so discard them.
      </p>
      <p>
        To delete data we have stored for a service integration, you must issue a delete
        request from the CLI. It will drop the table and remove its data from our
        database entirely.
      </p>
      <p>
        To remove all data, please contact us to close your account. We will remove all
        credentials, and all data we have stored on your behalf.
      </p>

      <p>
        We may contact you about our services or your activity. Some of these messages
        are required, transaction-related messages to customers. Any messages that are
        not required will contain unsubscribe links.
      </p>

      <h3>What Information We Share</h3>
      <p>
        We will never, ever share information sent from service integrations with 3rd
        parties.
      </p>
      <p>
        We will never sell or disclose any of your personal information to third parties
        without your explicit consent, except as specified in this policy.
      </p>
      <p>
        We may release your personal information to a third-party in order to comply
        with a subpoena or other legal requirement, or when we believe in good faith
        that such disclosure is necessary to comply with the law; prevent imminent
        physical harm or financial loss; or investigate or take action regarding illegal
        activities, suspected fraud, or violations of WebhookDB’s Terms & Conditions. We
        may disclose personally identifiable information to parties in compliance with
        our Copyright Policy, as we in our sole discretion believe necessary or
        appropriate in connection with an investigation of fraud, intellectual property
        infringement, piracy, or other unlawful activity.
      </p>
      <p>
        When we use other companies and people to perform tasks on our behalf, we may
        need to share your information with them to provide products and services to
        you. An example would include, but is not limited to, processing payments.
      </p>

      <h3>Cookies & Tracking Technologies</h3>
      <p>
        WebhookDB does not use cookie-based tracking technologies or services. We only
        collect basic anonymous usage statistics, and use private cookies for
        authentication.
      </p>

      <h3>Data Retention</h3>
      <p>
        WebhookDB will retain your information only for as long your account is active
        or as needed to provide you services. If you no longer want WebhookDB to use
        your information to provide you services, you can contact us to remove your
        account, or do it from the Command Line Interface. Your name and email address
        may be retained for diagnostic purposes for 90 days after you close an account.
      </p>

      <h3>Privacy Policy Changes</h3>
      <p>
        WebhookDB reserves the right to modify this privacy statement at any time. We’ll
        communicate changes by posting a notice on this page
        (https://webhookdb.com/privacy). If we make material changes to this policy you
        will be notified here, by email, or other places WebhookDB deems appropriate.
      </p>

      <h3>Contact Us</h3>
      <p>We welcome your questions or comments regarding this Privacy Policy:</p>
      <LegalContactText />
      <p>Effective as of July 7, 2021</p>
    </ContentPageLayout>
  );
}
/* eslint-enable react/no-unescaped-entities */
