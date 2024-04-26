# Changelog

All notable changes to WebhookDB will be described in this file,
include new integerations and features.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## Unreleased

## [1.3.0] - 2024-04-26

### Features and Replicators

* Go to `/admin` to see a new administrative interface by @rgalanakis in [#874)(https://github.com/webhookdb/webhookdb/pull/874), [#877)(https://github.com/webhookdb/webhookdb/pull/877), and [#878)(https://github.com/webhookdb/webhookdb/pull/878)
* Manage views from WebhookDB using `webhookdb saved-view`, by @rgalanakis in [#866)(https://github.com/webhookdb/webhookdb/pull/866)
* API /db/run_sql endpoint added, for safe CORS usage. by @rgalanakis in [#867)(https://github.com/webhookdb/webhookdb/pull/867) and [#868)(https://github.com/webhookdb/webhookdb/pull/868)
* Use OAuth in Increase replicators, and overhaul to new API shapes by @rgalanakis in [#882)(https://github.com/webhookdb/webhookdb/pull/882)
* Add `url_recorder_v1` replicator by @rgalanakis in [#898)(https://github.com/webhookdb/webhookdb/pull/898)
* Transistor: Add transcript text to table by @rgalanakis in [#864)(https://github.com/webhookdb/webhookdb/pull/864)

### Changes and Fixes

* Icalendar fixes:
  - Handle wrong encoding, handle 304s and 410s by @rgalanakis in [#865)(https://github.com/webhookdb/webhookdb/pull/865)
  - Implicit end dates handled by @rgalanakis in [#870)(https://github.com/webhookdb/webhookdb/pull/870)
  * Fix endless time calculation in ical rrule by @rgalanakis in [#880)(https://github.com/webhookdb/webhookdb/pull/880)
  * Retry instead of alerting on icalendar errors, and update Sentry by @rgalanakis in [#887)(https://github.com/webhookdb/webhookdb/pull/887)
  * Better error handling by @rgalanakis in [#889)(https://github.com/webhookdb/webhookdb/pull/889)
  * Delete stale cancelled events by @rgalanakis in [#891)(https://github.com/webhookdb/webhookdb/pull/891)
  * Better invalid unicode handling by @rgalanakis in [#893)(https://github.com/webhookdb/webhookdb/pull/893)
  * Ical rules, strip whitespace, developer alerts by @rgalanakis in [#897)(https://github.com/webhookdb/webhookdb/pull/897)
* Signalwire-Front Channel:
  * Alert admins on failure, fix dangling table on uninstall by @rgalanakis in [#879)(https://github.com/webhookdb/webhookdb/pull/879)
  * Handle null SW body by @rgalanakis in [#892)(https://github.com/webhookdb/webhookdb/pull/892)
* OAuth and related cleanup by @rgalanakis in [#881)(https://github.com/webhookdb/webhookdb/pull/881) and [#883)(https://github.com/webhookdb/webhookdb/pull/883)
* Intercom:
  * Fixes and log output reduction by @rgalanakis in [#884)(https://github.com/webhookdb/webhookdb/pull/884)
  * Handle the intercom contact.delete event by @rgalanakis in [#885)(https://github.com/webhookdb/webhookdb/pull/885)
  * Handle conversation.deleted events by @rgalanakis in [#886)(https://github.com/webhookdb/webhookdb/pull/886)
* Backfill job: Do not allow multiple backfills by @rgalanakis in [#871)(https://github.com/webhookdb/webhookdb/pull/871)
* Use admin instead of readonly dataset interally by @rgalanakis in [#872)(https://github.com/webhookdb/webhookdb/pull/872)
* Trim whitespace from API inputs by @rgalanakis in [#899)(https://github.com/webhookdb/webhookdb/pull/899)

## [1.2.2] - 2024-02-05

- Fix: There was a bug with the saved query migration. This eliminates an unnecessary unique constraint. ([b311b79d66](https://github.com/webhookdb/webhookdb/commit/b311b79d66082c67de41c0892412fa1ce785f76a))
- Performance: Saved queries use HTTP expires caching. ([738c3f0b](https://github.com/webhookdb/webhookdb/commit/738c3f0bf4a7b1da5c0d247b389dae22fde590d3))
- Fix: Do not restrict CORS origins on /v1/saved_queries. It should be safe for public saved queries
  to be called from anywhere, while private saved queries need auth anyway. ([738c3f0b](https://github.com/webhookdb/webhookdb/commit/738c3f0bf4a7b1da5c0d247b389dae22fde590d3))

## [1.2.1] - 2024-02-05

- Bump Webterm CLI version to 0.14.0 (needed to pick up Saved Query support)

## [1.2.0] - 2024-02-05

- Feature: Add support for Saved Queries. These can be used to expose specific queries over public or authed HTTP, for use in public dashboards and websites, where embedding a connection string for direct connection or using 'connection string auth' is unsuitable. ([#862](https://github.com/webhookdb/webhookdb/pull/862))
- Fix: PrepareDatabaseConnections job is idempotent by @rgalanakis in [#855](https://github.com/webhookdb/webhookdb/pull/855))
- Fix: Add 'recursive' to scheduled backfill spec by @rgalanakis in [#858](https://github.com/webhookdb/webhookdb/pull/858))
- Fix: Icalendar: Icalendar: Ignore 405 errors, nothing we can do ([6c591562](https://github.com/webhookdb/webhookdb/commit/6c591562e363b59819b3e57987c2e52c88271bb5))
- Performance: Icalendar: Improve operations of ICalendar syncs by @rgalanakis in [#860](https://github.com/webhookdb/webhookdb/pull/860))
- Chore: Positive UTC offsets on local machines by @rgalanakis in [#857](https://github.com/webhookdb/webhookdb/pull/857))
- Chore: Missing tests added to slightly improve coverage by @rgalanakis in [#852](https://github.com/webhookdb/webhookdb/pull/852))

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
