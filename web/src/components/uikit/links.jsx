import { Link as RRLink } from "react-router-dom";

import useFlexiHref from "../../state/useFlexHref.js";

/**
 * Render relative links using react-router-dom.
 */
export function RelLink({ href, ...rest }) {
  href = href || "#";
  const { isAbsoluteForm, relativeHref } = useFlexiHref(href);
  if (isAbsoluteForm) {
    console.error("RelLink requires relative links, got", href);
    href = "#";
  }
  return <RRLink to={relativeHref} {...rest} />;
}

/**
 * Render absolute links using a normal anchor.
 */
export function AbsLink({ href, ...rest }) {
  href = href || "#";
  const { isAbsoluteForm } = useFlexiHref(href);
  if (!isAbsoluteForm) {
    console.error("AbsLink requires absolute links, got", href);
    href = "#";
  }
  return <a href={href} {...rest} />;
}

/**
 * Render a link using:
 * - RelLink if the path is not absolute, like '/path' or 'path'.
 * - RelLink if the path is absolute, but starts with the current path,
 *   like 'http://localhost:19030/app/foo' being at 'http://localhost:19030'.
 * - AbsLink otherwise.
 */
export function FlexiLink({ href, absProps, relProps, ...rest }) {
  const { isActuallyRelative, relativeHref } = useFlexiHref(href);
  if (isActuallyRelative) {
    return <RelLink href={relativeHref} {...rest} {...relProps} />;
  }
  return <AbsLink href={href} {...rest} {...absProps} />;
}
