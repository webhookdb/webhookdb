import "../styles/custom.scss";

import { Button, Col, Row } from "react-bootstrap";

import CheckmarkSvg from "../components/CheckmarkSvg";
import React from "react";
import { SafeExternalLink } from "../components/links";
import Seo from "../components/Seo";
import WavesLayout from "../components/WavesLayout";
import staticData from "../components/staticData";
import useContactUs from "../components/useContactUs";

export default function Pricing() {
  const { render: renderContactUs, open: openContactUs } = useContactUs();
  return (
    <WavesLayout>
      <Seo title="Pricing" />
      <div className="d-flex justify-content-center">
        <Row className="mb-5 no-gutters" style={{ maxWidth: 1600 }}>
          <Col xs={12} md={6} xl={4}>
            <PricingCard
              title="Free"
              cta="Get Started"
              sub="Get started with WebhookDB with up to two integrations."
              features={[
                "Up to 2 free active integrations",
                "Unlimited storage for each integration*",
                "Upgrade anytime",
              ]}
            />
          </Col>
          <Col xs={12} md={6} xl={4}>
            <PricingCard
              title="Premium"
              cta="Get Started"
              sub="Upgrade to a paid subscription for $89/month or $890/year once you are ready."
              features={[
                "Unlimited active integrations",
                "Unlimited storage for each integration*",
                "Priority email support",
              ]}
            />
          </Col>
          <Col xs={12} md={{ span: 6, offset: 3 }} xl={{ span: 4, offset: 0 }}>
            <PricingCard
              title="Enterprise"
              cta="Contact Us"
              onCta={openContactUs}
              sub="If you have a ton of data, or other particular needs."
              features={[
                "Truly unlimited storage",
                "Write all data into your own database",
                "Phone support",
              ]}
            />
          </Col>
        </Row>
      </div>
      <p className="mt-4 ml-4 font-small">
        * In practice, if your database grows very large, we will work with you on
        upgrading your plan.{" "}
        <SafeExternalLink href={staticData.announcementBlog}>
          Learn more
        </SafeExternalLink>
        .
      </p>
      {renderContactUs()}
    </WavesLayout>
  );
}

function PricingCard({ title, cta, sub, features, onCta }) {
  return (
    <div className="d-flex justify-content-center pt-5 h-100">
      <div className="max-width-sm p-5 mx-2 shadow-lg rounded bg-light d-flex flex-column h-100">
        <h3 className="text-center">{title}</h3>
        <p className="lead">{sub}</p>
        {features.map((feature, idx) => (
          <React.Fragment key={feature}>
            <div>
              <CheckmarkSvg />
              <span className="m-2">{feature}</span>
            </div>
            {idx !== features.length - 1 && <hr className="w-100" />}
          </React.Fragment>
        ))}
        <div className="h-100" />
        <Button
          size="lg"
          block
          className="mt-5"
          href={onCta ? null : "/download"}
          onClick={onCta}
        >
          {cta}
        </Button>
      </div>
    </div>
  );
}
