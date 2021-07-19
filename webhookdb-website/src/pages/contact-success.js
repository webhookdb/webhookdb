import "../styles/custom.scss";

import { Button, Image } from "react-bootstrap";

import MailImage from "../images/mail.png";
import React from "react";
import Seo from "../components/Seo";
import WavesLayout from "../components/WavesLayout";

export default function ContactSuccess() {
  return (
    <WavesLayout>
      <Seo title="Contact Success" />
      <div className="text-center">
        <Image src={MailImage} className="mb-5 mt-5" fluid style={{ height: 350 }} />
        <p>
          Thanks, we&rsquo;s got your message, and will get in touch within 24 hours!
        </p>
        <Button href="/">Back to Home</Button>
      </div>
    </WavesLayout>
  );
}
