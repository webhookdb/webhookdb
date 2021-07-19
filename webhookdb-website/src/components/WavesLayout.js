import "../styles/custom.scss";

import { Container } from "react-bootstrap";
import LayoutPage from "../components/LayoutPage";
import React from "react";
import Waves from "../components/Waves";

export default function WavesLayout({ children }) {
  return (
    <LayoutPage>
      <Container fluid className="min-vh-80 p-0">
        <div
          style={{
            position: "absolute",
            width: "100%",
            zIndex: -1,
            overflow: "hidden",
          }}
        >
          <Waves height={500} />
        </div>
        {children}
      </Container>
    </LayoutPage>
  );
}
