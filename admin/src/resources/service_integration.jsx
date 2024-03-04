import { SimpleShowLayout } from "react-admin";

import { CDatagrid, CList, CShow } from "../components/admin";
import fieldList from "../modules/fieldList";

export const ServiceIntegrationList = () => (
  <CList>
    <CDatagrid>
      {fieldList(
        "id",
        ["reference", "organization", { reference: "organizations" }],
        "opaqueId",
        ["text", "serviceName", { sortable: false }],
        ["text", "tableName"],
      )}
    </CDatagrid>
  </CList>
);

export const ServiceIntegrationShow = () => (
  <CShow>
    <SimpleShowLayout>
      {fieldList(
        "id",
        ["reference", "organization", { reference: "organizations" }],
        "opaqueId",
        ["text", "serviceName"],
        ["text", "tableName"],
        "lastBackfilledAt",
        ["reference", "dependsOn", { reference: "service_integrations" }],
        ["boolean", "skipWebhookVerification"],
      )}
    </SimpleShowLayout>
  </CShow>
);
