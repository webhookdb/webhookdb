import { ReferenceManyField, SimpleShowLayout } from "react-admin";

import { CDatagrid, CList, CShow } from "../components/admin";
import fieldList from "../modules/fieldList";

export const MessageDeliveryList = () => (
  <CList>
    <CDatagrid>
      {fieldList(
        "id",
        ["datetime", "sentAt", { sortable: true }],
        ["text", "template"],
        ["email", "to"],
        ["reference", "recipient", { reference: "customers" }],
      )}
    </CDatagrid>
  </CList>
);

export const MessageDeliveryShow = () => (
  <CShow>
    <SimpleShowLayout>
      {fieldList(
        "id",
        "createdAt",
        "updatedAt",
        "sentAt",
        ["text", "template"],
        ["reference", "recipient", { reference: "customers" }],
        ["email", "to"],
        ["text", "transportService"],
        ["text", "transportMessageId"],
      )}
      <ReferenceManyField label="Bodies" reference="message_bodies" target="delivery_id">
        <CDatagrid>
          {fieldList(
            ["reference", "id", { label: "Body", reference: "message_bodies" }],
            ["text", "mediatype"],
          )}
        </CDatagrid>
      </ReferenceManyField>
    </SimpleShowLayout>
  </CShow>
);
