import identity from "lodash/identity";
import React from "react";

const makeCache = (store) => {
  return {
    /**
     * Return parsed JSON from local storage,
     * stored under the given key.
     * Return defaultValue on failure (not present, parse failure, etc).
     *
     * NOTE: The parsed value may be missing fields you expect,
     * either due to versioning issues, or browser stuff.
     * So always check or assign default values of complex objects.
     */
    getItem: (field, defaultValue = {}) => {
      return getItem(store, field, defaultValue);
    },
    setItem: (field, item) => {
      setItem(store, field, item);
    },
    removeItem: (field) => {
      try {
        store.removeItem(field);
      } catch (err) {
        console.log("Remove cache error:", err);
      }
    },
    clear: () => {
      try {
        store.clear();
      } catch (err) {
        console.log("Clear cache error:", err);
      }
    },
    /**
     *
     * @param {string} field
     * @param {string} initialValue
     * @param {function(any: string)=} convert
     * @returns {[string,function(string): void | any]}
     */
    useState: (field, initialValue, convert) => {
      convert = convert || identity;
      const [val, setVal] = React.useState(convert(getItem(store, field, initialValue)));
      const setValAndCache = (v) => {
        setItem(store, field, v);
        return setVal(v);
      };
      return [val, setValAndCache];
    },
  };
};

export const localStorageCache = makeCache(window.localStorage);

function getItem(store, field, defaultValue) {
  try {
    const cachedJSON = store.getItem(field);
    if (!cachedJSON) {
      return defaultValue;
    }
    return JSON.parse(cachedJSON);
  } catch (err) {
    console.log("Get cache error: ", err);
    return defaultValue;
  }
}

function setItem(store, field, item) {
  try {
    const itemJSON = JSON.stringify(item);
    store.setItem(field, itemJSON);
  } catch (err) {
    console.log("Set cache error: ", err);
  }
}
