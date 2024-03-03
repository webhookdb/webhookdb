import { FunctionField, SimpleShowLayout } from "react-admin";

import { CDatagrid, CList, CShow } from "../components/admin";
import fieldList from "../modules/fieldList";

export const MessageBodyList = () => (
  <CList>
    <CDatagrid>
      {fieldList(
        "id",
        ["reference", "delivery", { reference: "message_deliveries" }],
        ["text", "mediatype"],
      )}
    </CDatagrid>
  </CList>
);

export const MessageBodyShow = () => (
  <CShow>
    <SimpleShowLayout>
      {fieldList(
        "id",
        ["reference", "delivery", { reference: "message_deliveries" }],
        ["text", "mediatype"],
        <FunctionField key="rendered" label="Rendered Content" render={renderContent} />,
        ["code", "content", { label: "Raw Content" }],
      )}
    </SimpleShowLayout>
  </CShow>
);

function renderContent(o) {
  if (o.mediatype !== "text/html") {
    return "(same as raw)";
  }
  return <span dangerouslySetInnerHTML={{ __html: o.content }} />;
}
