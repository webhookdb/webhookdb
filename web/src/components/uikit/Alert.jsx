import { FontAwesomeIcon } from "@fortawesome/react-fontawesome";
import clsx from "clsx";
import { AnimatePresence } from "framer-motion";
import isUndefined from "lodash/isUndefined";
import React from "react";

import { faExclamationTriangle, faXmark } from "../icons.jsx";
import "./Alert.css";
import Button from "./Button.jsx";
import ShrinkingDiv from "./animate/ShrinkingDiv.jsx";
import { variantIcon } from "./theming.js";

/**
 * @param children
 * @param {string=} className
 * @param {string=} title Top text.
 * @param {string=} subtitle Text under the title.
 * @param {*=} icon Icon to show. If undefined, use the variant default.
 * @param {string|true=} primary Primary action label. Hide if empty. 'Confirm' if true.
 * @param {string|true=}secondary Secondary action label. Hide if empty. 'Deny' if true.
 * @param {boolean=} dismissable If true, alert can be dismissed.
 * @param {boolean=} show If given, use this value. If undefined, show the alert.
 * @param {('success'|'warning'|'error'|'primary')=} variant
 * @param onDismiss
 * @param onPrimary
 * @param onSecondary
 */
export default function Alert({
  children,
  className,
  title,
  subtitle,
  icon,
  primary,
  secondary,
  dismissable,
  show,
  variant,
  onDismiss,
  onPrimary,
  onSecondary,
}) {
  variant = variant || "primary";
  if (isUndefined(icon)) {
    icon = variantIcon(variant);
  } else if (icon === true) {
    icon = faExclamationTriangle;
  }

  show = isUndefined(show) ? true : show;
  const [innerShow, setInnerShow] = React.useState(show);
  primary = primary === true ? "Confirm" : primary;
  secondary = secondary === true ? "Deny" : secondary;
  subtitle = subtitle || children;

  function handleDismiss(e) {
    setInnerShow(false);
    onDismiss && onDismiss(e);
  }
  return (
    <AnimatePresence initial={false}>
      {innerShow && (
        <ShrinkingDiv key={title} className={clsx("alert", variant, className)}>
          <div className="flex row align-center">
            {icon && (
              <FontAwesomeIcon className={clsx("alert-icon", variant)} icon={icon} />
            )}
            <div className="flex column justify-center">
              {title && <p className="subtitle">{title}</p>}
              {subtitle && <p className={clsx("text", title && "mt-2")}>{subtitle}</p>}
            </div>
          </div>
          <div className="flex row gap-2 ml-3">
            {primary && (
              <Button variant="secondary" size="sm" onClick={onPrimary}>
                {primary}
              </Button>
            )}
            {secondary && (
              <Button variant="hollow-inverted" size="sm" onClick={onSecondary}>
                {secondary}
              </Button>
            )}
            {dismissable && (
              <Button
                variant="free-inverted"
                className={clsx(`alert-dismiss`, variant)}
                onClick={handleDismiss}
              >
                <FontAwesomeIcon icon={faXmark} />
              </Button>
            )}
          </div>
        </ShrinkingDiv>
      )}
    </AnimatePresence>
  );
}
