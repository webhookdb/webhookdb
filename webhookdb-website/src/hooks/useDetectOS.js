export default function useDetectOS() {
  if (window.navigator.appVersion.indexOf("Win") !== -1) {
    return "0";
  }
  if (window.navigator.appVersion.indexOf("Mac") !== -1) {
    return "1";
  }
  if (window.navigator.appVersion.indexOf("Linux") !== -1) {
    return "2";
  }

  return "3"; // any other distro
}
