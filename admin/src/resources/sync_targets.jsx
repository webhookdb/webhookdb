import { SimpleShowLayout } from "react-admin";

import { CDatagrid, CList, CShow } from "../components/admin";
import fieldList from "../modules/fieldList";

export const SyncTargetList = () => (
  <CList>
    <CDatagrid>
      {fieldList(
        "id",
        ["reference", "organization", { reference: "organizations" }],
        ["reference", "serviceIntegration", { reference: "service_integrations" }],
        ["text", "opaqueId"],
        "lastSyncedAt",
      )}
    </CDatagrid>
  </CList>
);

export const SyncTargetShow = () => (
  <CShow>
    <SimpleShowLayout>
      {fieldList(
        "id",
        ["reference", "organization", { reference: "organizations" }],
        ["reference", "serviceIntegration", { reference: "service_integrations" }],
        "createdAt",
        "updatedAt",
        "createdBy",
        ["text", "opaqueId"],
        ["number", "periodSeconds"],
        ["text", "schema"],
        ["text", "table"],
        "lastSyncedAt",
        ["text", "lastAppliedSchema"],
        ["number", "pageSize"],
      )}
    </SimpleShowLayout>
  </CShow>
);
