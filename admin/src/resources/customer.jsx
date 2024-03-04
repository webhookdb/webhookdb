import { ReferenceManyField, SimpleShowLayout } from "react-admin";

import { CDatagrid, CList, CShow } from "../components/admin";
import fieldList from "../modules/fieldList";

export const CustomerList = () => (
  <CList>
    <CDatagrid>
      {fieldList("id", ["email", "email", { sortable: true }], ["text", "name"])}
    </CDatagrid>
  </CList>
);

export const CustomerShow = () => (
  <CShow>
    <SimpleShowLayout>
      {fieldList(
        "id",
        "createdAt",
        "updatedAt",
        "softDeletedAt",
        ["text", "name"],
        ["email", "email"],
      )}
      <ReferenceManyField
        label="Memberships"
        reference="organization_memberships"
        target="customer_id"
      >
        <CDatagrid>
          {fieldList(
            [
              "reference",
              "id",
              { label: "Membership", reference: "organization_memberships" },
            ],
            ["reference", "organization", { reference: "organizations" }],
            ["reference", "membershipRole", { label: "Role", reference: "roles" }],
            ["boolean", "verified"],
            ["boolean", "isDefault"],
            ["text", "invitationCode"],
          )}
        </CDatagrid>
      </ReferenceManyField>
      <ReferenceManyField
        label="Roles"
        reference="customer_roles"
        target="customer_id"
        sortable={false}
        sort={{ field: "role_id", order: "ASC" }}
      >
        <CDatagrid>
          {fieldList(["reference", "role.id", { label: "Role", reference: "roles" }])}
        </CDatagrid>
      </ReferenceManyField>
    </SimpleShowLayout>
  </CShow>
);
