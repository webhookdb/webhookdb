import { SimpleShowLayout } from "react-admin";

import { CDatagrid, CList, CShow } from "../components/admin";
import fieldList from "../modules/fieldList";

export const RoleList = () => (
  <CList>
    <CDatagrid>{fieldList("id", ["text", "name"])}</CDatagrid>
  </CList>
);

export const RoleShow = () => (
  <CShow>
    <SimpleShowLayout>{fieldList("id", ["text", "name"])}</SimpleShowLayout>
  </CShow>
);
