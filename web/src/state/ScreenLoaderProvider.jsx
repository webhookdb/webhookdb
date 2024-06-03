import ScreenLoader from "../components/ScreenLoader.jsx";
import useToggle, {createToggle} from "./useToggle";
import React from "react";
import badContext from "../modules/badContext";

export const ScreenLoaderContext = React.createContext(
  {
    isOn: false,
    isOff: false,
    setState: badContext('', true),
    turnOn: () => badContext('', true),
    turnOff: () => badContext('', true),
    toggle: () => badContext('', true),
  }
);

export function ScreenLoaderProvider({ children }) {
  const toggle = useToggle(false);

  return (
    <ScreenLoaderContext.Provider value={toggle}>
      <ScreenLoader show={toggle.isOn} />
      {children}
    </ScreenLoaderContext.Provider>
  );
}
