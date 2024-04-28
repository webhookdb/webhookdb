import { SimpleShowLayout } from "react-admin";

import { CDatagrid, CList, CShow } from "../components/admin";
import fieldList from "../modules/fieldList";

export const SystemLogEventList = () => (
  <CList noSearch>
    <CDatagrid>
      {fieldList("id", "at", ["text", "title"], ["text", "body"], ["url", "link"])}
    </CDatagrid>
  </CList>
);

export const SystemLogEventShow = () => (
  <CShow>
    <SimpleShowLayout>
      {fieldList(
        "id",
        "at",
        ["text", "title"],
        ["text", "body"],
        ["url", "link"],
        ["reference", "actor", { reference: "customers" }],
      )}
    </SimpleShowLayout>
  </CShow>
);
