import { ReferenceManyField, SimpleShowLayout } from "react-admin";

import { CDatagrid, CList, CShow } from "../components/admin";
import fieldList from "../modules/fieldList";

export const OrganizationList = () => (
  <CList>
    <CDatagrid>{fieldList("id", ["text", "name"])}</CDatagrid>
  </CList>
);

export const OrganizationShow = () => (
  <CShow>
    <SimpleShowLayout>
      {fieldList(
        "id",
        ["text", "key", { sortable: true }],
        ["text", "name", { sortable: true }],
        "createdAt",
        "updatedAt",
        "softDeletedAt",
        ["email", "billingEmail"],
      )}
      <ReferenceManyField
        label="Memberships"
        reference="organization_memberships"
        target="organization_id"
      >
        <CDatagrid>
          {fieldList(
            ["reference", "id", { reference: "organization_memberships" }],
            ["reference", "customer", { reference: "customers" }],
            ["reference", "membershipRole", { reference: "roles" }],
            ["boolean", "verified"],
            ["text", "invitationCode"],
          )}
        </CDatagrid>
      </ReferenceManyField>
      <ReferenceManyField
        label="Service Integrations"
        reference="service_integrations"
        target="organization_id"
      >
        <CDatagrid>
          {fieldList(
            ["reference", "id", { reference: "service_integrations" }],
            "opaqueId",
            ["text", "serviceName"],
            ["text", "tableName"],
          )}
        </CDatagrid>
      </ReferenceManyField>
      <ReferenceManyField
        label="Database Tables"
        reference="replicated_databases"
        target="organization_id"
      >
        <CDatagrid>
          {fieldList(
            ["text", "tableName", { label: "Table" }],
            ["text", "sizePretty"],
            ["number", "size"],
          )}
        </CDatagrid>
      </ReferenceManyField>
    </SimpleShowLayout>
  </CShow>
);
