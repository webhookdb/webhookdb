import { Logger } from "../modules/logger";
import get from "lodash/get";
import isString from "lodash/isString";
import React from "react";

const logger = new Logger("errors");

export function useError(initialState) {
  const [error, setErrorInner] = React.useState(initialState || null);

  /**
   * @param {any=} e
   * @return {null}
   */
  const setError = React.useCallback(function setError(e) {
    setErrorInner(e);
    return null;
  }, []);
  return [error, setError];
}

/**
 * @return {string|null}
 */
export function extractErrorMessage(error) {
  if (!error || isString(error)) {
    return error;
  }
  if (get(error, "message") === "Network Error") {
    return "network_error";
  }
  const status = get(error, "response.data.status") || 500;
  let msg;
  if (status >= 500) {
    msg = defaultMessage;
  } else {
    msg = get(error, "response.data.message") || defaultMessage;
  }
  if (msg === defaultMessage) {
    // We couldn't parse anything meaningful, so log it out
    logger.error(error);
  }
  return msg;
}

const defaultMessage = "Sorry, something went wrong.";
