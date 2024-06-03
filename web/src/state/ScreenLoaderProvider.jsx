import React from "react";

import ScreenLoader from "../components/ScreenLoader.jsx";
import badContext from "../modules/badContext";
import useToggle from "./useToggle";

export const ScreenLoaderContext = React.createContext({
  isOn: false,
  isOff: false,
  setState: badContext("", true),
  turnOn: () => badContext("", true),
  turnOff: () => badContext("", true),
  toggle: () => badContext("", true),
});

export function ScreenLoaderProvider({ children }) {
  const toggle = useToggle(false);

  return (
    <ScreenLoaderContext.Provider value={toggle}>
      <ScreenLoader show={toggle.isOn} />
      {children}
    </ScreenLoaderContext.Provider>
  );
}
