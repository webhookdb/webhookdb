import clsx from "clsx";

import "./Form.css";

export default function Form({ className, colorMode, gap, children, ...rest }) {
  const cls = clsx(
    "form",
    `color-mode-${colorMode || "default"}`,
    gap && `gap-${gap}`,
    className,
  );
  return (
    <form className={cls} {...rest}>
      {children}
    </form>
  );
}

/**
 * @typedef {('default'|'inverted')} FormColorMode
 */
