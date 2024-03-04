import { SimpleShowLayout } from "react-admin";

import { CDatagrid, CList, CShow } from "../components/admin";
import fieldList from "../modules/fieldList";

export const DatabaseMigrationList = () => (
  <CList>
    <CDatagrid>
      {fieldList(
        "id",
        ["reference", "organization", { reference: "organizations" }],
        "startedAt",
        "updatedAt",
        "finishedAt",
      )}
    </CDatagrid>
  </CList>
);

export const DatabaseMigrationShow = () => (
  <CShow>
    <SimpleShowLayout>
      {fieldList(
        "id",
        ["reference", "organization", { reference: "organizations" }],
        "createdAt",
        "updatedAt",
        "startedAt",
        "finishedAt",
        ["reference", "startedBy", { reference: "customers" }],
        ["text", "organizationSchema"],
        ["number", "lastMigratedServiceIntegrationId"],
        [
          "reference",
          "lastMigratedServiceIntegration",
          { reference: "service_integrations" },
        ],
        ["datetime", "lastMigratedTimestamp"],
      )}
    </SimpleShowLayout>
  </CShow>
);
