import isString from "lodash/isString.js";
import React from "react";

import { faExclamationTriangle } from "../components/icons.jsx";
import { extractErrorMessage } from "./useError.jsx";
import useToast from "./useToast.jsx";

/**
 * @typedef ErrorToastState
 * @property {function(*, object=)} showErrorToast Show an error toast with the given string.
 *   If the value is a React element or string, use it verbatim.
 *   Otherwise, try to extractErrorMessage, and fall back to stringifying.
 */

/**
 * @returns {ErrorToastState}
 */
export default function useErrorToast() {
  const { showToast } = useToast();
  const showErrorToast = React.useCallback(
    (e) => {
      let st;
      if (React.isValidElement(e) || isString(e)) {
        st = e;
      } else {
        st = extractErrorMessage(e);
      }
      showToast({
        message: st,
        variant: "error",
        duration: 6000,
        title: "Error",
        icon: faExclamationTriangle,
      });
    },
    [showToast],
  );
  return { showErrorToast };
}
