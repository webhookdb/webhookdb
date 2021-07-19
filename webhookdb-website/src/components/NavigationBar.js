import "../styles/custom.scss";

import { Button, Image, Nav, NavLink, Navbar } from "react-bootstrap";

import Logo from "../images/whiteonwhite.png";
import React from "react";

export default function NavigationBar() {
  return (
    <div>
      <Navbar bg="primary" variant="dark" expand="md" className="pl-2 pr-4">
        <Nav.Link href="/">
          <Image src={Logo} fluid />
        </Nav.Link>
        <Navbar.Toggle aria-controls="basic-navbar-nav" />
        <Navbar.Collapse id="basic-navbar-nav">
          <Nav className="justify-content-end w-100">
            <Nav.Item className="align-self-center">
              <Nav.Link href="/docs/home" active>
                Documentation
              </Nav.Link>
            </Nav.Item>
            <Nav.Item className="align-self-center">
              <Nav.Link href="/pricing" active>
                Pricing
              </Nav.Link>
            </Nav.Item>
            <Nav.Item className="align-self-center">
              <NavLink href="/download" active>
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
