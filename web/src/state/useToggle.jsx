import React from "react";

/**
 * @param {boolean=} initial
 * @return {Toggle}
 */
export default function useToggle(initial) {
  const [isOn, setState] = React.useState(initial || false);
  const toggle = React.useMemo(
    () => createToggle(isOn, setState),
    [isOn],
  );
  return toggle;
}

/**
 *
 * @param {boolean} isOn
 * @param {function(boolean): void} setState
 * @returns {Toggle}
 */
export function createToggle(isOn, setState) {
  return {
    isOn,
    isOff: !isOn,
    setState,
    turnOn: () => setState(true),
    turnOff: () => setState(false),
    toggle: () => setState(!isOn),
  }
}

/**
 * @typedef Toggle
 * @property {function(): void} turnOff
 * @property {function(): void} turnOn
 * @property {function(): void} toggle
 * @property {function(boolean): void} setState
 * @property {boolean} isOn
 * @property {boolean} isOff
 */
