import { ReferenceManyField, SimpleShowLayout } from "react-admin";

import { CDatagrid, CList, CShow } from "../components/admin";
import fieldList from "../modules/fieldList";

export const WebhookSubscriptionList = () => (
  <CList>
    <CDatagrid>
      {fieldList(
        "id",
        ["reference", "organization", { reference: "organizations" }],
        ["reference", "serviceIntegration", { reference: "service_integrations" }],
        ["text", "opaqueId"],
        ["text", "deliverToUrl"],
      )}
    </CDatagrid>
  </CList>
);

export const WebhookSubscriptionShow = () => (
  <CShow>
    <SimpleShowLayout>
      {fieldList(
        "id",
        ["reference", "organization", { reference: "organizations" }],
        ["reference", "serviceIntegration", { reference: "service_integrations" }],
        "createdBy",
        "createdAt",
        "updatedAt",
        "deactivatedAt",
        ["text", "opaqueId"],
        ["text", "deliverToUrl"],
      )}
      <ReferenceManyField
        label="Deliveries"
        reference="webhook_subscription_deliveries"
        target="webhook_subscription_id"
      >
        <CDatagrid>
          {fieldList(
            [
              "reference",
              "id",
              { label: "Delivery", reference: "webhook_subscription_deliveries" },
            ],
            ["array", "attemptTimestamps"],
            ["array", "attemptHttpResponseStatuses"],
          )}
        </CDatagrid>
      </ReferenceManyField>
    </SimpleShowLayout>
  </CShow>
);
