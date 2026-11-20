import { SimpleShowLayout } from "react-admin";

import { CDatagrid, CList, CShow } from "../components/admin";
import fieldList from "../modules/fieldList";

export const SavedViewList = () => (
  <CList>
    <CDatagrid>
      {fieldList(
        "id",
        ["reference", "organization", { reference: "organizations" }],
        "createdBy",
        ["text", "name"],
      )}
    </CDatagrid>
  </CList>
);

export const SavedViewShow = () => (
  <CShow>
    <SimpleShowLayout>
      {fieldList(
        "id",
        ["reference", "organization", { reference: "organizations" }],
        "createdBy",
        "createdAt",
        "updatedAt",
        ["text", "name"],
        ["code", "sql"],
      )}
    </SimpleShowLayout>
  </CShow>
);
