import {
  debugRequestLogger,
  debugResponseLogger,
  errorResponseLogger,
} from "./apilogger";
import axios, { AxiosError, CanceledError } from "axios";
import humps from "humps";
import get from "lodash/get";
import noop from "lodash/noop";

function create(apiHost, config) {
  const { debug, chaos, ...rest } = config || {};
  const instance = axios.create({
    baseURL: apiHost,
    timeout: 20000,
    withCredentials: true,
    transformResponse: [
      ...axios.defaults.transformResponse,
      (data) => humps.camelizeKeys(data),
    ],
    transformRequest: [
      (data) => humps.decamelizeKeys(data),
      ...axios.defaults.transformRequest,
    ],
    ...rest,
  });
  if (debug) {
    console.log(
      "apiBase: Debug mode enabled, setting up Axios logging for calls to",
      apiHost,
    );
    instance.interceptors.request.use(...debugRequestLogger);
    instance.interceptors.response.use(...debugResponseLogger);
  } else {
    instance.interceptors.response.use(...errorResponseLogger);
  }
  if (chaos) {
    console.log(
      `apiBase: Chaos mode enabled (${chaos}), adding random delays to api calls`,
    );
    instance.interceptors.request.use(requestChaos(chaos));
  }
  return instance;
}

function requestChaos(chaos) {
  const chaosMult = isNaN(Number(chaos)) ? 1 : Number(chaos);
  return (reqConfig) => {
    // Add some delay into api calls to simulate real-world behavior.
    let debugDelay = 250 + Math.random() * 1000;
    // Add some p90 and p95 latencies
    const percentile = Math.random();
    if (percentile < 0.05) {
      debugDelay += 3000 + Math.random() * 4000;
    } else if (percentile < 0.1) {
      debugDelay += 1000 + Math.random() * 2000;
    }
    debugDelay *= chaosMult;
    return Promise.resolve(reqConfig).delay(debugDelay);
  };
}

function handleStatus(status, cb) {
  return (error) => {
    if (get(error, "response.data.error.status") === status) {
      return cb(error);
    }
    throw error;
  };
}

function mergeParams(params, o) {
  const cased = humps.decamelizeKeys(params || {});
  return { params: cased, ...o };
}

function isAxiosTimeout(r) {
  if (r instanceof CanceledError) {
    return true;
  }
  if (r instanceof AxiosError && r.code === "ECONNABORTED") {
    return true;
  }
  return false;
}

export default {
  create,
  handleStatus,
  isAxiosTimeout,
  mergeParams,
  pick: (s) => (o) => get(o, s),
  pickData: (o) => o.data,
  swallow: (status) => handleStatus(status, noop),
};
