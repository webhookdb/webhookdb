import { withSentry } from "./sentry";

export class Logger {
  constructor(name, options) {
    const { tags, context } = options || {};
    this.name = name;
    this._tags = tags || {};
    this._context = context || {};
  }

  tags(tags) {
    return new Logger(this.name, {
      tags: { ...this._tags, ...tags },
      context: this._context,
    });
  }

  context(context) {
    return new Logger(this.name, {
      tags: this._tags,
      context: { ...this._context, ...context },
    });
  }

  debug(event, fields) {
    console.debug(...this._buildConsoleMsg(event, fields));
  }

  info(event, fields) {
    console.log(...this._buildConsoleMsg(event, fields));
  }

  error(event, fields) {
    console.error(...this._buildConsoleMsg(event, fields));
    this._withSentry(function (sentry, ctx) {
      const allctx = { ...fields, ...ctx };
      sentry.captureMessage(event, allctx);
    });
  }

  exception(event, exc, fields) {
    this._withSentry(function (sentry, ctx) {
      sentry.captureException(exc, ctx);
    });
    console.error(...this._buildConsoleMsg(event, fields));
  }

  _buildConsoleMsg(event, fields) {
    fields = fields || {};
    const arr = [`[${this.name}]`, event];
    // Tags first because context can be big
    Object.entries(this._tags).forEach(([k, v]) =>
      arr.push(`${k}=${stringifyNonString(v)}`),
    );
    const ctx = { ...this._context, ...fields };
    Object.entries(ctx).forEach(([k, v]) =>
      arr.push(`${k}=${stringifyNonString(v)}`),
    );
    return arr;
  }

  _withSentry(cb) {
    withSentry((sentry) => {
      cb(sentry, {
        tags: { logger: this.name, ...this._tags },
        extra: this._context,
      });
    });
  }
}

function stringifyNonString(o) {
  return typeof o === "string" ? o : JSON.stringify(o);
}

window.CiroLogger = Logger;
