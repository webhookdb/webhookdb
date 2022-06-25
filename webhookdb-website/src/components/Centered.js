import { Col, Row } from "react-bootstrap";

import React from "react";

export default function Centered({ children }) {
  return (
    <Row className="justify-content-center bounded">
      <Col md={12} lg={10}>
        {children}
      </Col>
    </Row>
  );
}
