import useMountEffect from "./useMountEffect";
import React from "react";
import { ScreenLoaderContext } from "./ScreenLoaderProvider";

/**
 * @returns {Toggle}
 */
export default function useScreenLoader() {
  return React.useContext(ScreenLoaderContext);
}

export function withScreenLoaderMount(show) {
  show = show || false;
  return (Wrapped) => {
    return function ScreenLoader(props) {
      const loader = useScreenLoader();
      useMountEffect(() => {
        loader.setState(show);
      });
      return <Wrapped {...props} />;
    };
  };
}
