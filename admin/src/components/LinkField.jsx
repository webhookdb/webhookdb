import { Link } from "@mui/material";
import get from "lodash/get";
import { useRecordContext } from "react-admin";

import RLink from "./RLink";

export default function LinkField({ source, content, ...rest }) {
  const record = useRecordContext();
  let value = get(record, source);
  if (value == null) {
    return null;
  }

  const inner = get(record, content || source);
  let C;
  if (value.startsWith(window.location.origin)) {
    C = RLink;
    value = value.slice(window.location.origin.length);
  } else {
    C = Link;
  }
  return (
    <C href={value} {...rest}>
      {inner}
    </C>
  );
}

LinkField.defaultProps = { label: "" };
