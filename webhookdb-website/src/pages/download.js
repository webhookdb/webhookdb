import "../styles/custom.scss";

import { Accordion, Card, Container, Row } from "react-bootstrap";
import { FaApple, FaLinux, FaWindows } from "react-icons/fa";
import useDetectOS, { LINUX, MAC, WIN } from "../hooks/useDetectOS";

import CopyableCodeBlock from "../components/CopyableCodeBlock";
import { Link } from "gatsby";
import React from "react";
import { SafeExternalLink } from "../components/links";
import Seo from "../components/Seo";
import WavesLayout from "../components/WavesLayout";
import { defineCustomElements as deckDeckGoElement } from "@deckdeckgo/highlight-code/dist/loader";

export default function Download() {
  const defaultOS = useDetectOS();

  React.useEffect(() => {
    deckDeckGoElement().then(() => null);
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
            We recommend you first try WebhookDB online using our{" "}
            <Link to="/terminal">terminal in the browser</Link>. After you get started,
            download and install the CLI to keep going.
          </p>
          <p>
            The CLI source code is also availble{" "}
            <SafeExternalLink href="https://github.com/lithictech/webhookdb-cli">
              on GitHub
            </SafeExternalLink>
            .
          </p>
        </Card>
        <Accordion defaultActiveKey={defaultOS} className="mb-5">
          <PlatformCard Icon={FaApple} title="MacOS" eventKey={MAC}>
            <p>Easiest option is to use Homebrew:</p>
            <CopyableCodeBlock code="brew install lithictech/webhookdb-cli/webhookdb" />
            <ol>
              <li className="mb-3">
                Download the latest MacOS <code>tar.gz</code> file from{" "}
                <SafeExternalLink href={RELEASE}>{RELEASE}</SafeExternalLink>.
                <br />
                <strong>Make sure you choose the right architecture</strong>. M1 Macs
                use the ARM (<code>arm64</code>) binary, others use AMD (
                <code>x86_64</code>).
              </li>
              <li className="mb-3">
                Unzip the file:{" "}
                <code>tar -xvf webhookdb_X.X.X_macos_x86_64.tar.gz</code>.<br />
                For ARM (M1 Macs) it would be:{" "}
                <code>tar -xvf webhookdb_X.X.X_macos_arm64.tar.gz</code>
              </li>
              <li className="mb-3">
                Move <code>./webhookdb</code> to your execution path, like{" "}
                <code>/usr/local/bin</code>.
              </li>
            </ol>
          </PlatformCard>
          <PlatformCard Icon={FaLinux} title="Linux" eventKey={LINUX}>
            <ol>
              <li>
                Download the latest Linux <code>tar.gz</code> file from{" "}
                <SafeExternalLink href={RELEASE}>{RELEASE}</SafeExternalLink>
              </li>
              <li>
                Unzip the file:{" "}
                <code>tar -xvf webhookdb_X.X.X_linux_x86_64.tar.gz</code>
              </li>
              <li>
                Move <code>./webhookdb</code> to your execution path, like{" "}
                <code>/usr/local/bin</code>.
              </li>
            </ol>
          </PlatformCard>
          <PlatformCard Icon={FaWindows} title="Windows" eventKey={WIN}>
            <ol>
              <li>
                Download the latest Windows <code>zip</code> file from{" "}
                <SafeExternalLink href={RELEASE}>{RELEASE}</SafeExternalLink>
              </li>
              <li>
                Unzip the <code>webhookdb_X.X.X_windows_x86_64.zip</code> file.
              </li>
              <li>
                Run the unzipped <code>webhookdb.exe</code> file.
              </li>
            </ol>
          </PlatformCard>
        </Accordion>
      </Container>
    </WavesLayout>
  );
}

function PlatformCard({ Icon, title, eventKey, children }) {
  return (
    <Card>
      <Accordion.Toggle as={Card.Header} className="bg-light" eventKey={eventKey}>
        <Row className="align-items-center px-3">
          <Icon className="mr-2" /> {title}
        </Row>
      </Accordion.Toggle>
      <Accordion.Collapse eventKey={eventKey}>
        <Card.Body>{children}</Card.Body>
      </Accordion.Collapse>
    </Card>
  );
}

const RELEASE = "https://github.com/lithictech/webhookdb-cli/releases/latest";
