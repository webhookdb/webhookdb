import "../styles/custom.scss";

import { Accordion, Card, Container, Row } from "react-bootstrap";
import {
  FaApple,
  FaClipboard,
  FaClipboardCheck,
  FaLinux,
  FaWindows,
} from "react-icons/fa";

import { Link } from "gatsby";
import React from "react";
import Releases from "../components/Releases";
import { SafeExternalLink } from "../components/links";
import Seo from "../components/Seo";
import WavesLayout from "../components/WavesLayout";
import useDetectOS from "../hooks/useDetectOS";

export default function Download() {
  const [defaultOS, setdefaultOS] = React.useState("1");

  React.useEffect(() => {
    setdefaultOS(useDetectOS);
  }, []);

  return (
    <WavesLayout>
      <Seo title="Download" />
      <Container>
        <div style={{ height: 24 }} />
        <Card className="p-4 mb-3">
          <h2>Download WebhookDB CLI</h2>
          <p>Download the WebhookDB CLI for your platform.</p>
          <p>
            Check out <Link to="/docs/cli">instructions on getting started</Link>.
          </p>
          <p>
            You can also try WebhookDB online using our{" "}
            <Link to="/terminal">terminal in the browser</Link>.
          </p>
        </Card>
        <Accordion defaultActiveKey={defaultOS} className="mb-5">
          <Card>
            <Accordion.Toggle as={Card.Header} className="bg-light" eventKey="0">
              <Row className="align-items-center px-3">
                <FaWindows className="mr-2" /> Windows
              </Row>
            </Accordion.Toggle>
            <Accordion.Collapse className="bg-dark" eventKey="0">
              <Card.Body className="text-light">
                <p>TBD</p>
              </Card.Body>
            </Accordion.Collapse>
          </Card>
          <Card>
            <Accordion.Toggle as={Card.Header} className="bg-light" eventKey="1">
              <Row className="align-items-center px-3">
                <FaApple className="mr-2" /> MacOS
              </Row>
            </Accordion.Toggle>
            <Accordion.Collapse className="bg-dark" eventKey="1">
              <Card.Body className="text-light">
                <p>
                  It&rsquo;s simple to install webhookdb on Mac- we just need to
                  download and extract it to the right spot.
                </p>
                <p>
                  <strong>Make sure you choose the right architecture</strong>. M1 Macs
                  use the ARM process, others use AMD.
                </p>
                <p>For AMD:</p>
                <CodeBlock
                  text={`curl ${Releases.mac_amd} -s -L | tar xz -C ${Releases.mac_bindir} && chmod +x ${Releases.mac_bindir}/webhookdb`}
                />
                <p>For ARM (M1 Macs):</p>
                <CodeBlock
                  text={`curl ${Releases.mac_arm} -s -L | tar xz -C ${Releases.mac_bindir} && chmod +x ${Releases.mac_bindir}/webhookdb`}
                />
                <p>
                  You can also build from source, check it out{" "}
                  <SafeExternalLink href={Releases.source}>on GitHub</SafeExternalLink>.
                </p>
              </Card.Body>
            </Accordion.Collapse>
          </Card>
          <Card>
            <Accordion.Toggle as={Card.Header} className="bg-light" eventKey="2">
              <Row className="align-items-center px-3">
                <FaLinux className="mr-2" /> Linux
              </Row>
            </Accordion.Toggle>
            <Accordion.Collapse className="bg-dark" eventKey="2">
              <Card.Body className="text-light">
                <p>TBD</p>
              </Card.Body>
            </Accordion.Collapse>
          </Card>
        </Accordion>
      </Container>
    </WavesLayout>
  );
}

function CodeBlock({ text }) {
  const [checked, setChecked] = React.useState(false);
  function onClick() {
    navigator.clipboard.writeText(text);
    setChecked(true);
    window.setTimeout(() => setChecked(false), 3000);
  }
  const Comp = checked ? FaClipboardCheck : FaClipboard;
  return (
    <p className="mx-3">
      <Comp className="mr-4 d-block float-right cursor-pointer" onClick={onClick} />
      <code>{text}</code>
    </p>
  );
}
