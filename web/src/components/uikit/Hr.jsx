import clsx from "clsx";

import { ifEqElse } from "../../modules/fp.js";
import "./Hr.css";

export default function Hr({ className, mt, mb, my, ...rest }) {
  return (
    <hr
      className={clsx(
        "hr",
        ifEqElse(mb, true, "mb-3", `mb-${mb}`),
        ifEqElse(mt, true, "mt-3", `mt-${mt}`),
        ifEqElse(my, true, "my-3", `my-${my}`),
        className,
      )}
      {...rest}
    />
  );
}
