import { Col, Row } from "react-bootstrap";

import React from "react";
import WavesLayout from "../components/WavesLayout";

export default function ContentPageLayout({ children }) {
  return (
    <WavesLayout>
      <div>
        <Row className="mx-2 justify-content-md-center">
          <Col
            xs={12}
            md={10}
            lg={8}
            className="p-4 p-md-5 mt-5 shadow-lg rounded bg-light"
          >
            {children}
          </Col>
        </Row>
      </div>
    </WavesLayout>
  );
}
