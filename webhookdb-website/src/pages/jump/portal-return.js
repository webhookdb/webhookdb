import JumpPageLayout from "../../components/JumpPageLayout";
import React from "react";
import Seo from "../../components/Seo";

export default function PortalReturn() {
  return (
    <JumpPageLayout>
      <Seo title="Billing" />
      <p>You have successfully viewed or updated your billing information.</p>
      <p>You can close this page.</p>
    </JumpPageLayout>
  );
}
