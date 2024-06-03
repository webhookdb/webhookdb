import uniqueId from "lodash/uniqueId";
import React from "react";

export default function useUniqueId() {
  const uid = React.useMemo(() => uniqueId(), []);
  return uid;
}
