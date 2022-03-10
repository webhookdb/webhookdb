import React from "react";

export default function useDetectOS() {
  const val = React.useMemo(() => {
    const ua = navigator.userAgent;
    if (substrAny(ua, ["Win"])) {
      return WIN;
    }
    if (substrAny(ua, ["Mac"])) {
      return MAC;
    }
    if (substrAny(ua, ["Linux", "X11", "Unix", "UNIX"])) {
      return LINUX;
    }
    if (substrAny(ua, ["Android"])) {
      return ANDROID;
    }
    if (substrAny(ua, ["like Mac"])) {
      return IOS;
    }
    return OTHER;
  }, []);
  return val;
}

export const WIN = "windows";
export const MAC = "macos";
export const LINUX = "linux";
export const ANDROID = "android";
export const IOS = "ios";
export const OTHER = "other";

function substrAny(s, candidates) {
  return candidates.some((c) => s.indexOf(c) !== -1);
}
