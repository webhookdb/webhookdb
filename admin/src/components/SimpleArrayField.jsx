import get from "lodash/get";
import { useRecordContext } from "react-admin";

export default function SimpleArrayField({ source, render, getKey, ...rest }) {
  const record = useRecordContext();
  if (!render) {
    render = (x) => x;
  } else if (typeof render === "string") {
    const attr = render;
    render = (x) => x[attr];
  }
  if (!getKey) {
    getKey = (x, i) => `${i}${x}`;
  }
  return (
    <ul {...rest}>
      {get(record, source).map((item, i) => {
        const key = getKey(item, i);
        const val = render(item, i);
        return <li key={key}>{val}</li>;
      })}
    </ul>
  );
}
