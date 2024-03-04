import { FunctionField, SimpleShowLayout } from "react-admin";

import { CDatagrid, CList, CShow } from "../components/admin";
import brjoin from "../modules/brjoin";
import fieldList from "../modules/fieldList";

export const LoggedWebhookList = () => (
  <CList>
    <CDatagrid>
      {fieldList(
        "id",
        ["reference", "organization", { reference: "organizations" }],
        ["reference", "serviceIntegration", { reference: "service_integrations" }],
        "insertedAt",
        ["text", "requestMethod"],
        ["text", "requestPath"],
      )}
    </CDatagrid>
  </CList>
);

export const LoggedWebhookShow = () => (
  <CShow>
    <SimpleShowLayout>
      {fieldList(
        "id",
        ["reference", "organization", { reference: "organizations" }],
        ["reference", "serviceIntegration", { reference: "service_integrations" }],
        ["text", "serviceIntegrationOpaqueId"],
        "insertedAt",
        "truncatedAt",
        ["text", "requestMethod"],
        ["text", "requestPath"],
        <FunctionField
          label="Request headers"
          key="headers"
          render={(o) => brjoin(o.requestHeaders.map(([k, v]) => `${k}: ${v}`))}
        />,
        ["code", "requestBody"],
        ["number", "responseStatus"],
      )}
    </SimpleShowLayout>
  </CShow>
);
