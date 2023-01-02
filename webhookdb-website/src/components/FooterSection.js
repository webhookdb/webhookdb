import "../styles/custom.scss";

import { Col, Container, Image, Nav, Row } from "react-bootstrap";

import API2SQL from "./API2SQL";
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
            <Nav
              defaultActiveKey="/"
              className="flex-row justify-content-start justify-content-sm-around "
            >
              {[
                [
                  [
                    contactUsHref,
                    "Contact Us",
                    { onSelect: (_, e) => openContactUs(e) },
                  ],
                  ["/terms/", "Terms of Use"],
                  ["/privacy/", "Privacy Policy"],
                  ["/careers", "Careers"],
                  ["/licensing/", "Licensing and Partnering"],
                ],
                [
                  ["/docs/home/", "Documentation"],
                  ["https://github.com/lithictech/webhookdb-cli", "WebhookDB CLI"],
                  ["/docs/api2sql/", API2SQL],
                  ["/docs/faq/", "FAQ"],
                  ["/docs/super-webhooks/", "Super Webhooks"],
                  ["/integrations/", "Supported Integrations"],
                ],
                [
                  ["/solutions/analytics/", "WHDB Analytics"],
                  ["/solutions/app-startups", "WHDB Application Startups"],
                  ["/solutions/development-agencies", "WHDB Development Agencies"],
                  ["/solutions/digital-transformation", "WHDB Digital Transformation"],
                  ["/solutions/enterprises", "WHDB Enterprises"],
                  ["/solutions/fintech", "WHDB Fintech"],
                  ["/solutions/no-code", "WHDB No Code"],
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
