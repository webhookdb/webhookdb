import get from "lodash/get";
import { FunctionField } from "react-admin";

export default function CodeField({ source, sx, render, json, ...rest }) {
  let renderFunc;
  if (render) {
    renderFunc = render;
  } else if (json) {
    renderFunc = (o) => JSON.stringify(get(o, source), null, 2);
  } else {
    renderFunc = (o) => get(o, source);
  }
  return (
    <FunctionField
      source={source}
      render={renderFunc}
      component="code"
      sx={{ whiteSpace: "pre-wrap", fontFamily: "monospace", ...sx }}
      {...rest}
    />
  );
}

CodeField.defaultProps = { label: "" };
