# Changelog

All notable changes to WebhookDB will be described in this file,
include new integerations and features.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## Unreleased

(empty)

## [1.1.0] - 2024-01-19

- Front Signalwire Channel integration added. See <https://docs.webhookdb.com/guides/front-channel-signalwire/> ([24964420](https://github.com/webhookdb/webhookdb/commit/24964420))
- Add `ALERTING_MAX_ALERTS_PER_CUSTOMER_PER_DAY` to avoid sending many alerts to the same customer about the same replicator ([e5226f4b](https://github.com/webhookdb/webhookdb/commit/e5226f4b))
- Integration tests can be run from a gem ([98e606b1](https://github.com/webhookdb/webhookdb/commit/98e606b1))
- Backfilling race conditions are fixed by taking a lock on the job ([f18d6f1f](https://github.com/webhookdb/webhookdb/commit/f18d6f1f))
- Support local development via docker ([f5660f8d](https://github.com/webhookdb/webhookdb/commit/f5660f8d))
- ServiceIntegration#webhookdb_api_key column added ([5b98918](https://github.com/webhookdb/webhookdb/commit/5b98918))
- Add 'roll api key' endpoint for new `webhookdb_api_key` column ([fb1f96e](https://github.com/webhookdb/webhookdb/commit/fb1f96e))
- Front integrations are no longer hidden ([9ad8858](https://github.com/webhookdb/webhookdb/commit/9ad8858))
- Root url `/` redirects to `/terminal` ([84e5e85](https://github.com/webhookdb/webhookdb/commit/84e5e85))
- Disable auth by default during local dev ([1f39e5c](https://github.com/webhookdb/webhookdb/commit/1f39e5c))
- Debug endpoint echos headers in addition to body ([36f3e49](https://github.com/webhookdb/webhookdb/commit/36f3e49))
- Fix typo in OAuth customer install page, and use code tag ([7449da8](https://github.com/webhookdb/webhookdb/commit/7449da8))

## [1.0.2] - 2024-01-09

- Bump the terminal version to 0.13.0 ([577574bc](https://github.com/webhookdb/webhookdb/commit/577574bce8e8c2b13633749541d3bc4a8165a8ed))

## [1.0.1] - 2024-01-09

### Fixes

- Fix Heroku autoscaler configuration bugs, add tests ([5509849e](https://github.com/webhookdb/webhookdb/commit/5509849e9a019a73eb703e66174d897764d8823b))
- Fix varous issues in the Docker build, and improve where app-wide env vars (like the current git ref and sha) are pulled from in the environment, so it works when running via container or Heroku ([ff5bbb9d](https://github.com/webhookdb/webhookdb/commit/ff5bbb9d80acede9a260196b6698742bc49eebb7))

## [1.0.0] - 2024-01-08

Initial open-source release of WebhookDB. WebhookDB has been used in production
since 2021, so the changelog will start from this point forward.
