import "../styles/custom.scss";

import { Button, Col, Row } from "react-bootstrap";

import CheckmarkSvg from "../components/CheckmarkSvg";
import RLink from "../components/RLink";
import React from "react";
import Seo from "../components/Seo";
import WavesLayout from "../components/WavesLayout";
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
                "Unlimited storage for each integration",
                "API2SQL stored in a dedicated database",
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
                "Unlimited storage for each integration",
                "Write API2SQL into your own database",
                "Priority email support",
              ]}
            />
          </Col>
          <Col xs={12} md={{ span: 6, offset: 3 }} xl={{ span: 4, offset: 0 }}>
            <PricingCard
              title="Enterprise"
              cta="Contact Us"
              onCta={openContactUs}
              sub="Complete data and operational ownership for customers seeking more control."
              features={[
                "Run everything on your own servers",
                "Develop custom integrations",
                "Scale, source, and OEM licenses",
                "Phone support",
              ]}
            />
          </Col>
        </Row>
      </div>
      {renderContactUs()}
    </WavesLayout>
  );
}

function PricingCard({ title, cta, sub, features, onCta }) {
  return (
    <div className="d-flex justify-content-center pt-5 h-100">
      <div className="max-width-sm p-5 mx-2 shadow-lg rounded bg-light d-flex flex-column h-100">
        <h3 className="text-center">{title}</h3>
        <p className="lead mb-5">{sub}</p>
        <div className="h-100" />
        {features.map((feature, idx) => (
          <React.Fragment key={feature}>
            <div>
              <CheckmarkSvg />
              <span className="m-2">{feature}</span>
            </div>
            {idx !== features.length - 1 && <hr className="w-100" />}
          </React.Fragment>
        ))}
        <Button
          size="lg"
          block
          className="mt-5"
          href={onCta ? null : "/download"}
          onClick={onCta}
          as={RLink}
        >
          {cta}
        </Button>
      </div>
    </div>
  );
}
