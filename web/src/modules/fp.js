import isFunction from "lodash/isFunction";

/**
 * @template T
 * @param arr {Array<T>}
 * @param index {Number}
 * @param value {T}
 * @returns {Array<T>}
 */
export function arraySetAt(arr, index, value) {
  const result = arr.splice(0);
  result[index] = value;
  return result;
}

/**
 * @template T
 * @param arr {Array<T>}
 * @param index {Number}
 * @param value {T}
 * @returns {Array<T>}
 */
export function arrayMergeAt(arr, index, value) {
  const newItem = { ...arr[index], ...value };
  return arraySetAt(arr, index, newItem);
}

/**
 * @template T
 * @param arr {Array<T>}
 * @param value {T}
 * @returns {Array<T>}
 */
export function arrayAppend(arr, value) {
  const result = arr.splice();
  result.push(value);
  return result;
}

/**
 * @template T
 * @param arr {Array<T>}
 * @param index {Number}
 * @returns {Array<T>}
 */
export function arrayRemoveAt(arr, index) {
  const result = arr.slice();
  result.splice(index, 1);
  return result;
}

/**
 * @template T
 * @param m {Map<string,T>}
 * @param key {string}
 * @param value {T}
 * @returns {Map<string, h>}
 */
export function mapSetAt(m, key, value) {
  const result = { ...m, [key]: value };
  return result;
}

/**
 * If value equals target, return ifResult, else return elseResult.
 * Usually used like `ifEqElse(prop, true, defaultVal, prop)`
 * to get a default value if something is true.
 * @template T
 * @template U
 * @param value {*}
 * @param target {*}
 * @param ifResult {T}
 * @param elseResult {U}
 * @return {T|U}
 */
export function ifEqElse(value, target, ifResult, elseResult) {
  if (value === target) {
    return ifResult;
  }
  return elseResult;
}

/**
 * If value is undefined, return ifUndefined, else return value.
 * Usually used like `defaultUndefined(prop, false)`
 * to return a default if and only if the given value is undefined.
 * @template T
 * @template U
 * @param value {T}
 * @param ifUndefined {U}
 * @return {T|U}
 */
export function defaultUndefined(value, ifUndefined) {
  if (value === undefined) {
    return ifUndefined;
  }
  return value;
}

export function invokeIfFunc(f, ...args) {
  if (isFunction(f)) {
    return f(...args);
  }
  return f;
}
