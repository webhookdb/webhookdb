import React, { useCallback, useMemo } from "react";

import badContext from "../modules/badContext";
import { localStorageCache } from "../modules/localStorageHelper.js";

function invertColorMode(colorMode) {
  return colorMode === "light" ? "dark" : "light";
}

const DEFAULT_COLOR_MODE = "light";

export const GlobalViewStateContext = React.createContext({
  colorMode: DEFAULT_COLOR_MODE,
  invertedColorMode: invertColorMode(DEFAULT_COLOR_MODE),
  setColorMode: badContext("GlobalViewState", ""),
});

export default function GlobalViewStateProvider({ children }) {
  const [colorMode, setColorModeInner] = localStorageCache.useState(
    "color-mode",
    DEFAULT_COLOR_MODE,
  );
  const setColorMode = useCallback(
    (v) => {
      if (!v) {
        v = invertColorMode(colorMode);
      }
      document.querySelector("html").setAttribute("data-bs-theme", v);
      setColorModeInner(v);
    },
    [colorMode, setColorModeInner],
  );
  const invertedColorMode = invertColorMode(colorMode);
  const value = useMemo(
    () => ({
      colorMode,
      setColorMode,
      invertedColorMode,
    }),
    [colorMode, setColorMode, invertedColorMode],
  );
  return (
    <GlobalViewStateContext.Provider value={value}>
      {children}
    </GlobalViewStateContext.Provider>
  );
}
