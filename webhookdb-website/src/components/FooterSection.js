import "../styles/custom.scss";

import { Col, Container, Image, Nav, Row } from "react-bootstrap";

import Centered from "./Centered";
import { Link } from "gatsby";
import Logo from "../images/blueonwhite.png";
import RLink from "./RLink";
import React from "react";
import useContactUs from "./useContactUs";

export default function FooterSection() {
  const {
    render: renderContactUs,
    open: openContactUs,
    href: contactUsHref,
  } = useContactUs();

  return (
    <Container fluid className="bg-dark text-light p-3">
      {renderContactUs()}
      <Row className="justify-content-center align-items-center">
        <Col>
          <Centered>
            <Nav defaultActiveKey="/" className="flex-row justify-content-around">
              {[
                [
                  [
                    contactUsHref,
                    "Contact Us",
                    { onSelect: (_, e) => openContactUs(e) },
                  ],
                  ["/terms/", "Terms of Use"],
                  ["/privacy/", "Privacy Policy"],
                ],
                [
                  ["/docs/home/", "Documentation"],
                  ["/docs/new-paradigm/", "API-over-SQL"],
                  ["https://github.com/lithictech/webhookdb-cli", "WebhookDB CLI"],
                  ["/careers", "Careers"],
                ],
                [
                  ["/integrations/", "Supported Integrations"],
                  ["/app-startups/", "For Application Startups"],
                  ["/digital-transformation/", "For Digital Transformation"],
                  ["/development-agencies/", "For Development Agencies"],
                ],
              ].map((navs) => (
                <div className="d-flex flex-column" key={navs[0][0]}>
                  {navs.map(([href, text, rest]) => (
                    <Nav.Link
                      key={href}
                      eventKey={href}
                      className="text-light"
                      href={href}
                      as={RLink}
                      {...rest}
                    >
                      {text}
                    </Nav.Link>
                  ))}
                </div>
              ))}
            </Nav>
          </Centered>
          <Row className="justify-content-center my-4">
            <Link to="/">
              <Image src={Logo} />
            </Link>
          </Row>
          <Row className="justify-content-center my-3">
            <p> © {new Date().getFullYear()}</p>
          </Row>
        </Col>
      </Row>
    </Container>
  );
}
