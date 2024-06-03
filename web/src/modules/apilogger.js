import { Logger } from "./logger";
import get from "lodash/get";
import identity from "lodash/identity";
import omit from "lodash/omit";

const reqLogger = new Logger("api.requests");
const respLogger = new Logger("api.responses");

function reqSuccessDebug(config) {
  // https://github.com/axios/axios#request-config
  reqLogger
    .tags({ method: method(config), url: config.url })
    .debug("api_request");
  return config;
}

function reqError(error) {
  reqLogger.error(error);
  return Promise.reject(error);
}

function respSuccessDebug(response) {
  // https://github.com/axios/axios#response-schema
  let body = JSON.stringify(response.data);
  if (body.length > 103) {
    body = body.slice(0, 100) + "...";
  }
  respLogger
    .tags({
      method: method(response.config),
      url: response.config.url,
      status: response.status,
    })
    .context({ body })
    .info("api_response");
  return response;
}

function respErrorDebug(error) {
  if (error.response) {
    respSuccessDebug(error.response);
  } else {
    respLogger
      .tags({
        method: method(error.config),
        url: error.config.url,
        non_http_response_error: true,
      })
      .error(error.message);
  }
  return Promise.reject(error);
}

function method(c) {
  return c.method.toUpperCase();
}

export const debugRequestLogger = [reqSuccessDebug, reqError];
export const debugResponseLogger = [respSuccessDebug, respErrorDebug];

function respErrorFull(error) {
  if (get(error, "response.status") === 401) {
    return Promise.reject(error);
  }
  let tags = { method: method(error.config), url: error.config.url };
  if (!error.response) {
    tags.non_http_response_error = true;
    respLogger.tags(tags).error(error.message);
    return Promise.reject(error);
  }
  const apiErr = get(error, "response.data.error");
  if (apiErr) {
    tags = omit({ ...tags, ...apiErr }, "backtrace");
  }
  tags.status = error.response.status;
  respLogger
    .tags(tags)
    .context({ message: error.message })
    .error(`${tags.method} ${tags.url} ${tags.status}`);
  return Promise.reject(error);
}

export const errorResponseLogger = [identity, respErrorFull];
