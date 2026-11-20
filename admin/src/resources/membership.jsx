import { SimpleShowLayout } from "react-admin";

import { CDatagrid, CList, CShow } from "../components/admin";
import fieldList from "../modules/fieldList";

export const MembershipList = () => (
  <CList>
    <CDatagrid>
      {fieldList(
        "id",
        ["reference", "organization", { reference: "organizations" }],
        ["reference", "customer", { reference: "customers" }],
        ["reference", "membershipRole", { reference: "roles" }],
        ["text", "invitationCode"],
      )}
    </CDatagrid>
  </CList>
);

export const MembershipShow = () => (
  <CShow>
    <SimpleShowLayout>
      {fieldList(
        "id",
        ["reference", "organization", { reference: "organizations" }],
        ["reference", "customer", { reference: "customers" }],
        ["reference", "membershipRole", { reference: "roles" }],
        ["text", "invitationCode"],
        ["boolean", "verified"],
        ["boolean", "isDefault", { label: "Default" }],
      )}
    </SimpleShowLayout>
  </CShow>
);
