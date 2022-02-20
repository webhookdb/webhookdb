import { Container } from "react-bootstrap";
import LayoutPage from "../components/LayoutPage";
import React from "react";
import Seo from "../components/Seo";
import Webterm from "../components/Webterm";

export default function Terminal() {
  return (
    <LayoutPage center>
      <Seo title="WebhookDB Terminal" />
      <Container className="bg-light text-light pt-2 px-2" fluid>
        <div className="m-3">
          <Webterm width="100%" style={{ height: "80vh" }} />
        </div>
      </Container>
    </LayoutPage>
  );
}
