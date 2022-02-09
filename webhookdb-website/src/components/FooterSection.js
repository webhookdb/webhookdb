import "../styles/custom.scss";

import { Col, Container, Image, Nav, Row } from "react-bootstrap";

import Logo from "../images/blueonwhite.png";
import React from "react";
import useContactUs from "./useContactUs";

export default function FooterSection() {
  const { render: renderContactUs, open: openContactUs } = useContactUs();

  return (
    <Container fluid className="bg-dark text-light p-3">
      {renderContactUs()}
      <Row className="justify-content-center align-items-center">
        <Col>
          <Row className="justify-content-center">
            <Nav defaultActiveKey="/" className="flex-row">
              <Nav.Link
                eventKey="link-1"
                className="text-light"
                onSelect={openContactUs}
              >
                Contact Us
              </Nav.Link>
              <Nav.Link eventKey="link-2" className="text-light" href="/terms">
                Terms of Use
              </Nav.Link>
              <Nav.Link eventKey="link-2" className="text-light" href="/privacy">
                Privacy Policy
              </Nav.Link>
            </Nav>
          </Row>
          <Row className="justify-content-center my-3">
            <a href="/">
              <Image src={Logo} />
            </a>
          </Row>
          <Row className="justify-content-center my-3">
            <p> © {new Date().getFullYear()}</p>
          </Row>
        </Col>
      </Row>
    </Container>
  );
}
