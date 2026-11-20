import { SimpleShowLayout } from "react-admin";

import { CDatagrid, CList, CShow } from "../components/admin";
import fieldList from "../modules/fieldList";

export const WebhookDeliveryList = () => (
  <CList>
    <CDatagrid>
      {fieldList(
        "id",
        ["reference", "webhookSubscription", { reference: "webhook_subscriptions" }],
        ["array", "attemptTimestamps"],
        ["array", "attemptHttpResponseStatuses"],
      )}
    </CDatagrid>
  </CList>
);

export const WebhookDeliveryShow = () => (
  <CShow>
    <SimpleShowLayout>
      {fieldList(
        "id",
        ["reference", "webhookSubscription", { reference: "webhook_subscriptions" }],
        "createdAt",
        ["array", "attemptTimestamps"],
        ["array", "attemptHttpResponseStatuses"],
        ["json", "payload"],
      )}
    </SimpleShowLayout>
  </CShow>
);
