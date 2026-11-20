import { SimpleShowLayout } from "react-admin";

import { CDatagrid, CList, CShow } from "../components/admin";
import fieldList from "../modules/fieldList";

export const SavedQueryList = () => (
  <CList>
    <CDatagrid>
      {fieldList(
        "id",
        ["reference", "organization", { reference: "organizations" }],
        "createdBy",
        ["text", "opaqueId"],
        ["text", "description"],
      )}
    </CDatagrid>
  </CList>
);

export const SavedQueryShow = () => (
  <CShow>
    <SimpleShowLayout>
      {fieldList(
        "id",
        ["reference", "organization", { reference: "organizations" }],
        "createdBy",
        "createdAt",
        "updatedAt",
        ["text", "opaqueId"],
        ["text", "description"],
        ["boolean", "public"],
        ["code", "sql"],
      )}
    </SimpleShowLayout>
  </CShow>
);
