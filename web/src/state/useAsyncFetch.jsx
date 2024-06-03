import React from "react";

import { arrayAppend, arrayRemoveAt, arraySetAt, mapSetAt } from "../modules/fp.js";

/**
 * @param makeRequest
 * @param {object=} options
 * @param {object=} options.fetchArgs Pass these to makeRequest.
 * @param {boolean=} options.doNotFetchOnInit If true, do not fetch right away.
 * @param {boolean|function=} options.handleError Use to avoid the 'unhandled rejected promise' error.
 *   If a function, call it with the failing API response.
 *   If true, assume the failure is handled elsewhere.
 * @returns {{state, asyncFetch, error, loading, fetched, fetchedState}}
 */
const useAsyncFetch = (makeRequest, options) => {
  let { doNotFetchOnInit, fetchArgs, handleError } = options || {};
  const [fetchedState, setFetchedState] = React.useState({});
  const [scratchState, setScratchStateInner] = React.useState({});
  const [error, setError] = React.useState(null);
  const [loading, setLoading] = React.useState(!doNotFetchOnInit);

  const fetchArgsKey = JSON.stringify(fetchArgs);

  const stableMakeRequest = React.useCallback(
    (...args) => {
      if (fetchArgs) {
        return makeRequest(fetchArgs);
      } else {
        return makeRequest(...args);
      }
    },
    [makeRequest, fetchArgsKey], // eslint-disable-line
  );

  const replaceState = React.useCallback((st) => {
    setFetchedState(st);
    setScratchStateInner({});
  }, []);

  const setScratchState = React.useCallback(
    (st) => {
      setScratchStateInner({ ...scratchState, ...st });
    },
    [scratchState],
  );

  const asyncFetch = React.useCallback(
    (...args) => {
      setLoading(true);
      setError(false);
      let p = stableMakeRequest(...args)
        .then((resp) => {
          const st = resp.data;
          replaceState(st);
          return st;
        })
        .tapCatch((e) => setError(e))
        .tap(() => setLoading(false))
        .tapCatch(() => setLoading(false));
      if (handleError === true) {
        p = p.catch(() => null);
      } else if (handleError) {
        p = p.catch(handleError);
      }
      return p;
    },
    [stableMakeRequest, handleError, replaceState],
  );

  React.useEffect(() => {
    if (!doNotFetchOnInit) {
      asyncFetch();
    }
  }, [asyncFetch, doNotFetchOnInit]);
  return {
    fetchedState,
    replaceState,
    asyncFetch,
    error,
    loading,
    fetched: !loading && !error,
    scratchState,
    setScratchState,
    combinedState: { ...fetchedState, ...scratchState },
  };
};

export default useAsyncFetch;

export function useAsyncCollectionFetch(makeRequest, options) {
  const {
    fetchedState,
    replaceState,
    asyncFetch,
    error,
    loading,
    fetched,
    scratchState,
    setScratchState,
  } = useAsyncFetch(makeRequest, options);

  const items = fetchedState.items || emptyArray;
  const scratchItems = scratchState.items || emptyArray;
  const replaceItemAt = React.useCallback(
    (index, value) => {
      replaceState(mapSetAt(fetchedState, "items", arraySetAt(items, index, value)));
    },
    [fetchedState, items, replaceState],
  );
  const setScratchItemAt = React.useCallback(
    (index, value) => {
      setScratchState(
        mapSetAt(scratchState, "items", arraySetAt(scratchItems, index, value)),
      );
    },
    [scratchItems, scratchState, setScratchState],
  );
  const combinedItemAt = React.useCallback(
    (index) => {
      return { ...items[index], ...scratchItems[index] };
    },
    [items, scratchItems],
  );
  const appendScratchItem = React.useCallback(
    (value) => {
      mapSetAt(scratchState, "items", arrayAppend(scratchItems, value));
    },
    [scratchItems, scratchState],
  );
  const removeScratchItem = React.useCallback(
    (index) => {
      mapSetAt(scratchState, "items", arrayRemoveAt(scratchItems, index));
    },
    [scratchItems, scratchState],
  );

  return {
    error,
    loading,
    fetched,
    asyncFetch,
    items,
    scratchItems,
    replaceItemAt,
    setScratchItemAt,
    combinedItemAt,
    appendScratchItem,
    removeScratchItem,
  };
}

const emptyArray = [];
