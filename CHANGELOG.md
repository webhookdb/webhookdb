# Changelog

All notable changes to WebhookDB will be described in this file,
include new integerations and features.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## Unreleased

## [1.0.1] - 2024-01-09

### Fixes

- Fix Heroku autoscaler configuration bugs, add tests (5509849e9a019a73eb703e66174d897764d8823b)
- Fix varous issues in the Docker build, and improve where app-wide env vars (like the current git ref and sha) are pulled from in the environment, so it works when running via container or Heroku (ff5bbb9d80acede9a260196b6698742bc49eebb7)

## [1.0.0] - 2024-01-08

Initial open-source release of WebhookDB. WebhookDB has been used in production
since 2021, so the changelog will start from this point forward.
