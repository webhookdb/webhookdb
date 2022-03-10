import { Col, Row } from "react-bootstrap";

import React from "react";
import WavesLayout from "../components/WavesLayout";

export default function JumpPageLayout({ children }) {
  return (
    <WavesLayout>
      <div>
        <Row className="mx-2 justify-content-md-center">
          <Col
            xs={{ offset: 1, span: 10 }}
            md={{ offset: 0, span: 8 }}
            lg={5}
            xl={4}
            className="p-4 p-md-5 mt-5 shadow-lg rounded bg-light"
          >
            {children}
          </Col>
        </Row>
      </div>
    </WavesLayout>
  );
}
