import humps from "humps";
import { fetchUtils } from "ra-core";

import config from "../config";

/**
 * Run apiFetch but decamelize and serialize the given body, if not null.
 * Promise resolves with camelized JSON.
 * @param {string} urlTail
 * @param {object|null} body
 * @param {RequestInit} options
 * @return {Promise<* | {}>}
 */
export function apiFetchJson(urlTail, body, options) {
  if (body !== null) {
    const snakeBody = humps.decamelizeKeys(body);
    options.body = JSON.stringify(snakeBody);
  }
  return apiFetch(urlTail, options).then(({ json }) => humps.camelizeKeys(json));
}

/**
 * Calls the API using the given options, and returns a promise as per fetchUtils.fetchJson.
 * @param {string} urlTail URL part like '/admin_api/v1/data_provider/get_one'
 * @param {RequestInit} options
 */
export function apiFetch(urlTail, options) {
  const url = `${config.apiHost}${urlTail}`;
  const opts = {
    credentials: "include",
    ...options,
  };
  return fetchUtils.fetchJson(url, opts);
}
