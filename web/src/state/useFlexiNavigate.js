import React from "react";
import { useNavigate } from "react-router-dom";

/**
 * Like react-router useNavigate, but strips the basename before calling navigate.
 * This is necessary because, while react-router-dom Link components
 * can get a route like /foo and will prepend the basename to use an actual
 * href of '/app/foo', other link components may not.
 * Even if they navigate properly using react-router's useNavigate(),
 * they will have either 1) an incorrect href like '/foo' that goes to the right route at '/app/foo',
 * or 2) a correct href like '/app/foo' that is an invalid route ('/app/app/foo').
 *
 * @return {function}
 */
export default function useFlexiNavigate() {
  const rrnavigate = useNavigate();
  const navigate = React.useCallback(
    (href, options) => {
      if (BASENAME && typeof href === "string" && href.startsWith(BASENAME)) {
        href = href.slice(BASENAME.length);
      }
      return rrnavigate(href, options);
    },
    [rrnavigate],
  );
  return navigate;
}
const BASENAME = import.meta.env.BASE_URL.replace(/\/$/, "");
