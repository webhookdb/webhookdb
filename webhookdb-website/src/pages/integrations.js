import "../styles/custom.scss";

import { Col, Image, Row } from "react-bootstrap";

import Lead from "../components/Lead";
import React from "react";
import Seo from "../components/Seo";
import WavesHeaderLayout from "../components/WavesHeaderLayout";
import integrations from "../modules/integrations";
import useContactUs from "../components/useContactUs";

export default function Integrations() {
  const {
    render: renderContactUs,
    open: openContactUs,
    href: contactUsHref,
  } = useContactUs();
  return (
    <WavesHeaderLayout
      header={
        <>
          <h1>Supported Integrations</h1>
          <Lead>
            We currently support the following integrations, with more released every
            week. If you need a service or resource not listed below, please{" "}
            <a
              href={contactUsHref}
              onClick={openContactUs}
              className="text-light font-weight-bold"
            >
              Contact Us
            </a>
            .
          </Lead>
          <Lead>
            Adding new integrations for most services is pretty simple and we should be
            able to add what you need within two days.
          </Lead>
        </>
      }
    >
      <Seo title="Integrations" />
      <Row className="justify-content-sm-center justify-content-xs-start align-items-start mt-3">
        {integrations.map((integration, idx) => {
          return (
            <Col key={idx} className="col-12 col-sm-6 col-md-4 col-lg-4">
              <Image
                src={integration.logo}
                className="mb-3 img-fluid"
                style={{ maxHeight: 80 }}
              />
              <div className="lead font-weight-bold mb-5">
                {integration.resources.join(", ")}
              </div>
            </Col>
          );
        })}
      </Row>
      <Lead>
        Some listed integrations are still in beta, so you may not see them in
        WebhookDB. Please{" "}
        <a href={contactUsHref} onClick={openContactUs}>
          Contact Us
        </a>{" "}
        if you need access, or want any API not listed here.
      </Lead>
      {renderContactUs()}
    </WavesHeaderLayout>
  );
}
