import { FontAwesomeIcon } from "@fortawesome/react-fontawesome";
import clsx from "clsx";
import { Button as RAButton } from "react-aria-components";

import { faChevronLeft, faChevronRight } from "../icons.jsx";
import "./Button.css";
import { FlexiLink } from "./links.jsx";

/**
 * @param {string=} className
 * @param {boolean=} disabled
 * @param {Size=} size
 * @param {('primary'|'secondary'|'hollow'|'free'|'link'|'hollow-inverted'|'free-inverted'|'light'|'danger'|'info')} variant
 * @param {boolean|Icon=} leftArrow If true, show the 'left' chevron, if an icon definition use that.
 * @param {boolean|Icon=} rightArrow Same as leftArrow but for the right.
 * @param {boolean=} href Use an 'a' instead of a button.
 * @param children
 * @param rest
 */
export default function Button({
  className,
  disabled,
  size,
  variant,
  leftArrow,
  rightArrow,
  href,
  children,
  ...rest
}) {
  variant = variant || "primary";
  const cls = clsx(
    "btn",
    href && "btn-link",
    `btn-${size || "md"}`,
    `btn-${variant}`,
    className,
  );

  const arrowcls = clsx(`btn-arrow`, !disabled && `btn-arrow-${variant}`);

  let C;
  const typeProps = {};
  if (href) {
    C = FlexiLink;
    typeProps.href = href;
    if (disabled) {
      typeProps["aria-disabled"] = true;
      typeProps.onClick = (e) => e.preventDefault();
    }
  } else {
    C = RAButton;
    if (disabled) {
      typeProps.isDisabled = true;
    }
  }

  return (
    <C className={cls} {...typeProps} {...rest}>
      {leftArrow && (
        <FontAwesomeIcon
          className={clsx(arrowcls)}
          icon={chooseIcon(leftArrow, faChevronLeft)}
        />
      )}
      {children}
      {rightArrow && (
        <FontAwesomeIcon
          className={clsx(arrowcls)}
          icon={chooseIcon(rightArrow, faChevronRight)}
        />
      )}
    </C>
  );
}

function chooseIcon(val, fallback) {
  if (val?.icon) {
    return val;
  }
  return fallback;
}
