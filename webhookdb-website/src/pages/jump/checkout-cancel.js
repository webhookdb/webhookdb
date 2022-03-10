import JumpPageLayout from "../../components/JumpPageLayout";
import React from "react";
import Seo from "../../components/Seo";

export default function CheckoutCancel() {
  return (
    <JumpPageLayout>
      <Seo title="Checkout Canceled" />
      <p>You have canceled your checkout process.</p>
      <p>You can close this page.</p>
    </JumpPageLayout>
  );
}
