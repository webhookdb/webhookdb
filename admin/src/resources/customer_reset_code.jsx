import { SimpleShowLayout } from "react-admin";

import { CDatagrid, CList, CShow } from "../components/admin";
import fieldList from "../modules/fieldList";

export const CustomerResetCodeList = () => (
  <CList>
    <CDatagrid>
      {fieldList(
        "id",
        ["reference", "customer", { reference: "customers" }],
        ["text", "token"],
        ["boolean", "used"],
        "expireAt",
      )}
    </CDatagrid>
  </CList>
);

export const CustomerResetCodeShow = () => (
  <CShow>
    <SimpleShowLayout>
      {fieldList(
        "id",
        ["reference", "customer", { reference: "customers" }],
        "createdAt",
        "updatedAt",
        "expireAt",
        ["text", "token"],
        ["boolean", "used"],
      )}
    </SimpleShowLayout>
  </CShow>
);
