import { SimpleShowLayout } from "react-admin";

import { CDatagrid, CList, CShow } from "../components/admin";
import fieldList from "../modules/fieldList";

export const BackfillJobList = () => (
  <CList>
    <CDatagrid>
      {fieldList(
        "id",
        ["reference", "organization", { reference: "organizations" }],
        ["reference", "serviceIntegration", { reference: "service_integrations" }],
        "startedAt",
        "finishedAt",
      )}
    </CDatagrid>
  </CList>
);

export const BackfillJobShow = () => (
  <CShow>
    <SimpleShowLayout>
      {fieldList(
        "id",
        ["reference", "organization", { reference: "organizations" }],
        ["reference", "serviceIntegration", { reference: "service_integrations" }],
        "createdAt",
        "updatedAt",
        "startedAt",
        "finishedAt",
        ["text", "opaqueId"],
        ["boolean", "incremental"],
        ["reference", "parentJob", { reference: "backfill_jobs" }],
        "createdBy",
      )}
    </SimpleShowLayout>
  </CShow>
);
