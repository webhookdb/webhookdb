import "../styles/custom.scss";

import CtaAction from "../components/CtaAction";
import React from "react";
import Seo from "../components/Seo";
import WavesHeaderLayout from "../components/WavesHeaderLayout";

export default function GetStarted() {
  return (
    <WavesHeaderLayout header={<CtaAction alt className="mb-4" />}>
      <Seo title="Get Started" />
      <div />
    </WavesHeaderLayout>
  );
}
