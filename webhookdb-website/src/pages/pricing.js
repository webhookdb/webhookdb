import "../styles/custom.scss";

import { Button, Col, Row } from "react-bootstrap";

import CheckmarkSvg from "../components/CheckmarkSvg";
import { Link } from "gatsby";
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
          <Col xs={12} md={6} xl={{ span: 5, offset: 1 }}>
            <PricingCard
              title="Hosted/SaaS"
              cta="Get Started"
              sub="Unlimited use on the fully hosted version of WebhookDB."
              features={[
                "Unlimited number of integrations",
                "Unlimited storage for each integration",
                "API2SQL stored in a dedicated database",
                "Zero-downtime upgrade anytime",
              ]}
              footer={
                <span>
                  Learn why{" "}
                  <Link to="/licensing/">
                    we offer unlimited use on the hosted version
                  </Link>
                  .
                </span>
              }
            />
          </Col>
          <Col xs={12} md={6} xl={5}>
            <PricingCard
              title="Self-Hosted/Enterprise"
              cta="Contact Us"
              onCta={openContactUs}
              sub="Complete data and operational ownership."
              features={[
                "Run everything on your own servers",
                "Develop custom integrations",
                "Flexible Scale, Source, and OEM licenses",
                "Phone support",
              ]}
              footer={
                <span>
                  Read more on{" "}
                  <Link to="/licensing/">
                    our committment to supporting our partners
                  </Link>
                  .
                </span>
              }
            />
          </Col>
        </Row>
      </div>
      {renderContactUs()}
    </WavesLayout>
  );
}

function PricingCard({ title, cta, sub, features, footer, onCta }) {
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
          className="mt-4"
          href={onCta ? null : "/download"}
          onClick={onCta}
          as={RLink}
        >
          {cta}
        </Button>
        <div className="mt-4">{footer}</div>
      </div>
    </div>
  );
}
