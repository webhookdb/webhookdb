import "../styles/custom.scss";

import { Button, Image, Nav, NavDropdown, NavLink, Navbar } from "react-bootstrap";

import Lead from "./Lead";
import Logo from "../images/whiteonwhite.png";
import RLink from "./RLink";
import React from "react";
import clsx from "clsx";

export default function NavigationBar() {
  const itemCls = "align-self-end align-self-md-center text-right";
  return (
    <div className="bg-primary sitenav">
      <Navbar bg="primary" variant="dark" expand="md" className="pl-2 pr-4 bounded">
        <Nav.Link href="/" as={RLink}>
          <Image src={Logo} fluid />
        </Nav.Link>
        <Navbar.Toggle aria-controls="basic-navbar-nav" />
        <Navbar.Collapse id="basic-navbar-nav">
          <Nav className="justify-content-end w-100">
            <NavDropdown
              title="Products"
              id="products-dropdown"
              className={clsx(itemCls, "nav-dropdown nav-link-hover-invert")}
            >
              <NavDropdownItem
                href="/pricing"
                title="Starter Edition"
                text="Hosted WebhookDB gives you a taste of a better way to integrate APIs."
              />
              <Sep />
              <NavDropdownItem
                href="/pricing"
                title="Partner Edition"
                text="Self-hosted WebhookDB with a larger catalogue of available integrations."
              />
              <Sep />
              <NavDropdownItem
                href="/pricing"
                title="Enterprise Edition"
                text="Custom integrations for any internal or external API on the planet."
              />
              <Sep />
              <NavDropdownItem
                href="/integrations"
                title="Integrations"
                text="See what public integrations we currently support."
              />
            </NavDropdown>
            <NavDropdown
              title="Learn"
              id="learn-dropdown"
              className={clsx(itemCls, "nav-dropdown nav-link-hover-invert")}
            >
              <NavDropdownItem
                href="/docs/api2sql"
                title="API2SQL Architecture"
                text="Welcome to a new, superior paradigm for API integration."
              />
              <Sep />
              <NavDropdownItem
                href="/docs/api-reservoir"
                title="API Data Reservoir"
                text="Like a reservoir collects water and makes using it as simple as turning a tap, so WebhookDB does for API data."
              />
              <Sep />
              <NavDropdownItem
                href="/terminal"
                title="Terminal"
                text="Try WebhookDB's CLI directly from your browser."
              />
              <Sep />
              <NavDropdownItem
                href="/docs/home"
                title="Documentation"
                text="Browse all WebhookDB guides and documentation."
              />
              <Sep />
              <NavDropdownItem
                href="/docs/cli"
                title="Guide: Intro & Tutorial"
                text="Step-by-step walkthrough to get started syncing and using data with WebhookDB."
              />
              <Sep />
              <NavDropdownItem
                href="/docs/self-hosting"
                title="Guide: Self Hosting"
                text="Learn how to self-host WebhookDB on your own database and/or infrastructure."
              />
              <Sep />
              <NavDropdownItem
                href="/docs/integrating"
                title="Guide: Integrating WebhookDB"
                text="Learn how to integrate your WebhookDB database into your applications, analytics, and unit tests."
              />
            </NavDropdown>
            <Nav.Item className={itemCls}>
              <Nav.Link href="/pricing" as={RLink} className="nav-link-hover-invert">
                Pricing
              </Nav.Link>
            </Nav.Item>
            <Nav.Item className={itemCls}>
              <NavLink href="/download" as={RLink} className="nav-link-nohover">
                <Button className="rounded-pill" variant="outline-light">
                  Download
                </Button>
              </NavLink>
            </Nav.Item>
          </Nav>
        </Navbar.Collapse>
      </Navbar>
    </div>
  );
}

function NavDropdownItem({ title, text, href }) {
  return (
    <NavDropdown.Item href={href} as={RLink}>
      <Lead className="mb-1">{title}</Lead>
      <p style={{ whiteSpace: "normal" }} className="mb-0">
        {text}
      </p>
    </NavDropdown.Item>
  );
}

function Sep() {
  return <hr className="mx-3" />;
}
