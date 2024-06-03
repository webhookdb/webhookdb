import { FontAwesomeIcon } from "@fortawesome/react-fontawesome";
import clsx from "clsx";
import isUndefined from "lodash/isUndefined";

import { faXmark } from "../icons.jsx";
import Button from "./Button.jsx";
import "./Toast.css";
import { variantIcon } from "./theming.js";

export default function Toast({ title, message, variant, icon, onDismiss }) {
  variant = variant || "info";
  icon = isUndefined(icon) ? variantIcon(variant) : icon;
  return (
    <div className={clsx("toast", `toast-${variant}`)}>
      <div className="flex row align-center">
        {icon && (
          <FontAwesomeIcon className={clsx("toast-icon", "toast-icon2")} icon={icon} />
        )}
        <div className={clsx("flex column justify-center")}>
          {title && <p className="subtitle">{title}</p>}
          {message && <p className={clsx("text", title && "mt-1")}>{message}</p>}
        </div>
      </div>
      {onDismiss && (
        <Button className={clsx("px-1 ml-3 dismiss")} variant="free" onClick={onDismiss}>
          <FontAwesomeIcon icon={faXmark} />
        </Button>
      )}
    </div>
  );
}
