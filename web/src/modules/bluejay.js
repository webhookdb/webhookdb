export function installPromiseExtras(Promise) {
  Promise.delay = function delay(durationMs, p) {
    p = p || Promise.resolve();
    return p.then((r) => {
      return new Promise((resolve) => {
        window.setTimeout(() => resolve(r), durationMs);
      });
    });
  };

  Promise.prototype.delay = function delay(durationMs) {
    return Promise.delay(durationMs, this);
  };

  Promise.delayOr = function delayOr(durationMs, otherPromise, options) {
    options = options || { buffer: 100 };
    const started = Date.now();
    return otherPromise.then((r) => {
      const waited = Date.now() - started;
      const stillLeftToWait = durationMs - waited;
      // If we have a number of milliseconds or less than buffer left to wait,
      // we can return the original result without delay, because we know we took about durationMs.
      if (stillLeftToWait <= options.buffer) {
        return r;
      }
      // Otherwise, we should delay until the intended elapsed time has been reached.
      return Promise.delay(stillLeftToWait, r);
    });
  };

  Promise.prototype.delayOr = function delayOr(durationMs, options) {
    return Promise.delayOr(durationMs, this, options);
  };

  Promise.prototype.tap = function tap(f) {
    return this.then((v) => {
      f(v);
      return v;
    });
  };

  Promise.prototype.tapCatch = function tapCatch(f) {
    return this.catch((r) => {
      f(r);
      return Promise.reject(r);
    });
  };

  Promise.prototype.tapTap = function tapTap(f) {
    return this.tap(f).tapCatch(f);
  };
}
