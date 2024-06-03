import React from "react";
import { GlobalViewStateContext } from "./GlobalViewStateProvider";

/**
 * @typedef GlobalViewState
 * @property {Element=} navElement The navigation element.
 * @property {function(Element=): void} setNavElement
 * @property {string=} colorMode 'dark' or 'light'
 * @property {function(string=): void} setColorMode Use no argument to toggle.
 */

/**
 * Global view state manages global state about the view,
 * like the DOM elements for navigation.
 * @returns {GlobalViewState}
 */
export default function useGlobalViewState() {
  return React.useContext(GlobalViewStateContext);
}
