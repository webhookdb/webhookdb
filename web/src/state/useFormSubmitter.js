import React from "react";

import useErrorToast from "./useErrorToast.jsx";
import useScreenLoader from "./useScreenLoader.jsx";
import useToast from "./useToast.jsx";

export default function useFormSubmitter() {
  const screenLoader = useScreenLoader();
  const { showErrorToast } = useErrorToast();
  const { showToast } = useToast();

  const prepareSubmit = React.useCallback(
    (event) => {
      if (event) {
        event.preventDefault();
      }
      screenLoader.turnOn();
    },
    [screenLoader],
  );

  const handleSubmitError = React.useCallback(
    (e) => {
      showErrorToast(e);
      screenLoader.turnOff();
    },
    [screenLoader, showErrorToast],
  );

  /**
   * @type {function(string=): void|*}
   */
  const showSuccessToast = React.useCallback(
    (message) => showToast({ message: message || "Changes saved", variant: "success" }),
    [showToast],
  );

  const o = React.useMemo(
    () => ({
      prepareSubmit,
      handleSubmitError,
      showErrorToast,
      showSuccessToast,
      turnOffScreenLoader: screenLoader.turnOff,
    }),
    [
      handleSubmitError,
      prepareSubmit,
      screenLoader.turnOff,
      showErrorToast,
      showSuccessToast,
    ],
  );
  return o;
}
