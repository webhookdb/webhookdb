import React from "react";
import FirstSection from "../components/FirstSection";
import SecondSection from "../components/SecondSection";
import LayoutPage from "../components/LayoutPage";
import "../styles/custom.scss";
import IntegrationsSection from "../components/IntegrationsSection";
import Helmet from "react-helmet";
import Seo from "../components/Seo";

export default function IndexPage() {
  return (
    <LayoutPage>
      <Seo
        title=""
        meta={[
          {
            name: "keywords",
            content:
              "web development, software, website, web app, monolith, microservices, ruby, rails, python, django, go, golang, stripe, twilio, shopify",
          },
        ]}
      />
      <Helmet>
        <title>WebhookDB</title>
      </Helmet>
      <FirstSection />
      <IntegrationsSection />
      <SecondSection />
    </LayoutPage>
  );
}
