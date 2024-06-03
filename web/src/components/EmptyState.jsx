import clsx from "clsx";

import Button from "./uikit/Button.jsx";
import Stack from "./uikit/Stack.jsx";

export default function EmptyState({
  message,
  children,
  gotoDashboard,
  cta,
  ctaHref,
  className,
  ...rest
}) {
  message = message || children;
  if (gotoDashboard) {
    cta = "Go to dashboard";
    ctaHref = "/dashboard";
  }
  return (
    <Stack className={clsx("align-center", className)} {...rest}>
      <p className="subtitle mb-5">{message}</p>
      {cta && (
        <div>
          <Button href={ctaHref}>{cta}</Button>
        </div>
      )}
    </Stack>
  );
}
