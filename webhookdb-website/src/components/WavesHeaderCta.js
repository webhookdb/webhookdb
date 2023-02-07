import { Button } from "react-bootstrap";
import CenteredDiv from "./CenteredDiv";
import RLink from "./RLink";
import React from "react";

export default function WavesHeaderCta({ href, children }) {
  return (
    <CenteredDiv className="mb-3">
      <Button
        href={href || "/get-started"}
        variant="secondary"
        size="lg"
        className="mt-2 cta"
        as={RLink}
      >
        {children || "Get in touch"}
      </Button>
    </CenteredDiv>
  );
}
