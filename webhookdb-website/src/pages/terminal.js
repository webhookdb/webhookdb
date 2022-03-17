import { Container } from "react-bootstrap";
import LayoutPage from "../components/LayoutPage";
import React from "react";
import Seo from "../components/Seo";
import Webterm from "../components/Webterm";
import { Link } from "gatsby";
import useContactUs from "../components/useContactUs";

export default function Terminal() {
  const { render: renderContactUs, open: openContactUs } = useContactUs();
  return (
    <LayoutPage center>
      <Seo title="WebhookDB Terminal" />
      <Container className="pt-2 px-2" fluid>
        <div className="m-3">
          <p className="font-small mb-1">
            This is a fully functional terminal for WebhookDB. When you close your tab,
            your session is removed. If you&rsquo;d prefer something local, you should{" "}
            <Link to="/download">download the CLI</Link>.
          </p>
          <p className="font-small mb-2">
            Check out <Link to="/docs/home">how to get started</Link>, or{" "}
            <a href="#" onClick={openContactUs}>
              contact us
            </a>{" "}
            or email <a href="mailto:webhookdb@lithic.tech">webhookdb@lithic.tech</a> if
            you run into any problems.
          </p>
          <Webterm width="100%" style={{ height: "80vh" }} autofocus />
          {renderContactUs()}
        </div>
      </Container>
    </LayoutPage>
  );
}
