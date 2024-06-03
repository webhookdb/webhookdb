import clsx from "clsx";
import { Label } from "react-aria-components";

import "./InputFieldLabel.css";

export default function InputFieldLabel({ label, children, className, ...rest }) {
  return (
    <Label className={clsx("input-field-label", className)} {...rest}>
      {label || children}
    </Label>
  );
}
