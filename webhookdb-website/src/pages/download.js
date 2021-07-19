import "../styles/custom.scss";

import { Accordion, Card, Container, Row } from "react-bootstrap";
import { FaApple, FaLinux, FaWindows } from "react-icons/fa";

import React from "react";
import { Releases } from "../components/Releases";
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
            Check out <a href="/docs/cli">instructions on getting started</a>.
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
                <p>To install the Stripe CLI on Windows:</p>
                <ol>
                  <li>
                    <Card.Link href={Releases.windows}>Download </Card.Link>
                    the latest windows tar.gz file
                  </li>
                  <li>Unzip the webhookdb_windows_amd64.zip file</li>
                  <li>Run the unzipped .exe file</li>
                </ol>
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
                <p>To install the Stripe CLI on MacOS (AMD Processor):</p>
                <ol>
                  <li>
                    <Card.Link href={Releases.mac_amd}>Download </Card.Link>
                    the latest MacOS AMD file
                  </li>
                  <li>Unzip the file: tar -xvf webhookdb_darwin_amd64.zip</li>
                </ol>
                <hr />
                <p>To install the Stripe CLI on MacOS (ARM Processor):</p>
                <ol>
                  <li>
                    <Card.Link href={Releases.mac_arm}>Download </Card.Link>
                    the latest MacOS ARM file
                  </li>
                  <li>Unzip the file: tar -xvf webhookdb_darwin_arm64.zip</li>
                </ol>
                <p>
                  Optionally, install the binary in a location where you can execute it
                  globally (e.g., /usr/local/bin).
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
                <p>To install the Stripe CLI on Linux (AMD Processor):</p>
                <ol>
                  <li>
                    <Card.Link href={Releases.linux_amd}>Download </Card.Link>
                    the latest linux AMD file
                  </li>
                  <li>Unzip the file: tar -xvf webhookdb_linux_amd64.zip</li>
                  <li>Run the executable ./webhookdb</li>
                </ol>
                <hr />
                <p>To install the Stripe CLI on Linux (ARM Processor):</p>
                <ol>
                  <li>
                    <Card.Link href={Releases.linux_arm}>Download </Card.Link>
                    the latest linux ARM file
                  </li>
                  <li>Unzip the file: tar -xvf webhookdb_linux_arm64.zip</li>
                  <li>Run the executable ./webhookdb</li>
                </ol>
              </Card.Body>
            </Accordion.Collapse>
          </Card>
        </Accordion>
      </Container>
    </WavesLayout>
  );
}
