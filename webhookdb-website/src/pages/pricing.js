import React from "react";
import "../styles/custom.scss";
import { Row, Col, Button } from "react-bootstrap";
import CheckmarkSvg from "../components/CheckmarkSvg";
import WavesLayout from "../components/WavesLayout";
import Seo from "../components/Seo";

export default function Pricing() {
  return (
    <WavesLayout>
      <Seo title={"Pricing"} />
      <Row className="mb-5 no-gutters">
        <Col xs={12} md={6}>
          <div className="d-flex justify-content-center justify-content-md-end pt-5 h-100">
            <PricingCard
              title="Free"
              cta="Get Started"
              sub="Get started with WebhookDB with up to two integrations."
              features={[
                "Up to 2 free active integrations",
                "Unlimited storage for each integration",
              ]}
            />
          </div>
        </Col>
        <Col xs={12} md={6}>
          <div className="d-flex justify-content-center justify-content-md-start pt-5 h-100">
            <PricingCard
              title="Premium"
              cta="Get Started"
              sub="Upgrade to a paid subscription for $25/month once you are ready."
              features={[
                "Unlimited active integrations",
                "Unlimited storage for each integration",
                "Phone support",
              ]}
            />
          </div>
        </Col>
      </Row>
    </WavesLayout>
  );
}

function PricingCard({ title, cta, sub, features }) {
  return (
    <div
      className={
        "max-width-sm p-5 mx-2 shadow-lg rounded bg-light d-flex flex-column h-100"
      }
    >
      <h3 className={"text-center"}>{title}</h3>
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
      <Button size="lg" block className={"mt-5"} href="/download">
        {cta}
      </Button>
    </div>
  );
}
