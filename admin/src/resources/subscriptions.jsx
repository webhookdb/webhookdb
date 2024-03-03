import { SimpleShowLayout } from "react-admin";

import { CDatagrid, CList, CShow } from "../components/admin";
import fieldList from "../modules/fieldList";

export const SubscriptionList = () => (
  <CList>
    <CDatagrid>
      {fieldList(
        "id",
        ["reference", "organization", { reference: "organizations" }],
        ["text", "stripeId"],
        ["text", "stripeCustomerId"],
      )}
    </CDatagrid>
  </CList>
);

export const SubscriptionShow = () => (
  <CShow>
    <SimpleShowLayout>
      {fieldList(
        "id",
        ["reference", "organization", { reference: "organizations" }],
        "createdAt",
        "updatedAt",
        "softDeletedAt",
        ["text", "stripeId"],
        ["text", "stripeCustomerId"],
        ["json", "stripeJson"],
      )}
    </SimpleShowLayout>
  </CShow>
);
