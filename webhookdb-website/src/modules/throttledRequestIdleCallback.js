/**
 * Invoke requestIdleCallback(cb) after a timeout has elapsed.
 * @param cb
 * @param timeout
 */
export default function throttledRequestIdleCallback(cb, timeout) {
  window.setTimeout(() => {
    requestIdleCallback(cb);
  }, timeout);
}
