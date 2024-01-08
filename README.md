[![Latest Release](https://img.shields.io/github/v/release/webhookdb/webhookdb?color=blue&sort=semver)](https://github.com/webhookdb/webhookdb/releases/latest)
[![Gem Version](https://badge.fury.io/rb/webhookdb.svg)](https://badge.fury.io/rb/webhookdb)
[![Build](https://github.com/webhookdb/webhookdb/actions/workflows/deploy-dockerhub.yml/badge.svg)](https://hub.docker.com/r/webhookdb/webhookdb/tags)
[![Tests](https://github.com/webhookdb/webhookdb/actions/workflows/backend-checks.yml/badge.svg)](https://github.com/webhookdb/webhookdb/actions/workflows/backend-checks.yml)
[![Coverage](https://codecov.io/gh/webhookdb/webhookdb/graph/badge.svg?token=TQUCNZ8ESF)](https://codecov.io/gh/webhookdb/webhookdb)
[![Docs](https://img.shields.io/badge/docs-purple)](https://docs.webhookdb.com)

# WebhookDB

Replicate any API to your database with WebhookDB.

WebhookDB handles webhooks and intelligently polls APIs to provide
a normalized, schematized, relational copy of API data.

No new APIs to learn -- just an easy-to-use CLI to set up integrations,
and then you get a database connection string to access your data.
WebhookDB keeps everything up to date, automatically.

WebhookDB is designed to be easily self-hosted (seriously, you can even
[deploy to Heroku](https://docs.webhookdb.com/docs/operating-webhookdb/deploy-heroku) within seconds),
or used through [WebhookDB Cloud](https://webhookdb.com).

Explore the extensive documentation at <https://docs.webhookdb.com>.

## Quick Start

The easiest way to get started is to use the Docker Compose file,
which uses the latest [webhookdb image](https://hub.docker.com/repository/docker/webhookdb/webhookdb/general)
and starts up dependencies.

```
$ docker compose -f docker/docker-compose-demo.yml up 
```

Then go to <http://localhost:18101/terminal>, and run:

```
> webhookdb auth login
```

The demo Docker Compose file mode will automatically set up some datasets you can browse.

To replicate API data, see what is available with `webhookdb services list`,
and set up a replicator with `webhookdb integrations create`.

```
> webhookdb services list
> webhookdb integrations create <service name>
```

## Documentation

Visit <https://docs.webhookdb.com> to see the docs.

## Deployment

WebhookDB is designed to be easy to deploy. You just need a way to run a container,
some configuration, a Postgres database, and Redis.

To build a configuration file, and deploy directly to Platform-as-a-Service platforms like Heroku,
visit <https://webhookdb.com/deploy-builder>.

## License

Licensed under [Apache 2.0](/webhookdb/webhookdb/blob/main/LICENSE)

Copyright 2020, Lithic Technology
