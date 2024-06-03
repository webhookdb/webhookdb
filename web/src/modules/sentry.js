import * as Sentry from "@sentry/react";
import React from "react";
import {
  createRoutesFromChildren,
  matchRoutes,
  useLocation,
  useNavigationType,
} from "react-router-dom";

/**
 * Call cb(Sentry), and console log if there is any sort of error.
 * @param {function(Sentry)} cb
 */
export function withSentry(cb) {
  if (!Sentry) {
    console.warn("sentry was not available");
    return;
  }
  try {
    cb(Sentry);
  } catch (e) {
    console.error("Error calling Sentry:", e);
  }
}

/**
 * Conditionally initialize Sentry.
 * See https://docs.sentry.io/platforms/javascript/configuration/options/ for options.
 */
export function initSentry({ dsn, release, environment, ...rest }) {
  if (!dsn) {
    return;
  }
  Sentry.init({
    dsn,
    release,
    environment,
    maxBreadcrumbs: 50,
    sampleRate: 1.0,
    integrations: [
      new Sentry.BrowserTracing({
        // See docs for support of different versions of variation of react router
        // https://docs.sentry.io/platforms/javascript/guides/react/configuration/integrations/react-router/
        routingInstrumentation: Sentry.reactRouterV6Instrumentation(
          React.useEffect,
          useLocation,
          useNavigationType,
          createRoutesFromChildren,
          matchRoutes,
        ),
      }),
      new Sentry.Replay(),
    ],
    ...rest,
  });
}
