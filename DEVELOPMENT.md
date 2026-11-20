# WebhookDB Architecture and Development

Various details about how some parts of WebhookDB are built.
Sometimes the docs are on classes, sometimes they're here.

## Local Development

We use the Makefile for every important development command since
Makefiles are a wonderful high-level task runner.

- This is set up as a standard Ruby (**not Rails**) app, and should work out of the box on most machines.
- You can run with a local Ruby install, or through a 'development' Docker container.
  - You can install the right Ruby version through `rbenv` (`.ruby-version`)
    or `asdf` (`.tool-versions`), or you can run through Docker.
  - If you run into problems with `make install` (usually due to native extension building),
    you can try with the Docker container. It should be more reliable,
    though is never as nice as true local development.
- Service dependencies are listed in `docker-compose.yml`.
  - We take a 'services are on localhost' approach, even in Docker.
    It makes it much easier to work with the services, like using web interfaces.
- The process (Ruby or Docker) needs to be restarted when you make changes.
  We do not use an auto-reloader. Most development should be done with unit tests,
  so iterating a live server should be rare.

Running with a local Ruby install:

```
$ make install    # Install gems and dependencies
$ make up         # Start docker compose services

$ make migrate-test   # Migrate the test database
$ make test           # Run unit tests

$ make release                # Migrate the database
$ make run                    # Runs the web process
$ make run-workers            # Runs worker processes, you should do this in another window
$ open http://localhost:18001 # Opens a browser to the hosted temrinal
```

Running with Docker, all of the above commands can be called with
`make dockerdev-%` or `make dockertest-%`.
The make target strings after `dockerdev-` and `dockertest-`
are passed through to the underlying container (ie, `make dockertest-test` runs `make test`
in the container, which is running with the proper environment.

```
$ make up                   # Start docker compose services
$ make dockerdev-build      # Build a dev/test container with gems built into it

$ make dockertest-migrate-test   # Migrate the test database
$ make dockertest-test           # Run tests

$ make dockerdev-release         # Migrate the database
$ make dockerdev-run             # Runs the web process
$ make dockerdev-run-workers     # Runs worker process, you should do this another window
$ open http://localhost:18001    # Opens a browser to the hosted temrinal
```

## Configuration

As a good 12-factor app, environment variables are used exclusively,
along with `.env` files.

Add a `.env.development.local` file to provide git-ignored configuration.

## Auth

All WebhookDB auth is done with OTP to the customer email (no passwords):

- `webhookdb auth <email>`
- Error if they are logged in
- Creates an unverified `Customer` if there is none with that email
- Dispatches a OTP to the email
- Customer checks their email, finds a numeric code
- Customer enters that code into the CLI prompt
- Customer is authed and verified
- Token (cookie) is stored on their machine

## Integration Tests

We have integration tests set up that give the entire stack a pretty decent exercise.
See the `/integration` folder for the tests.

The tests can be run locally:

- Run `make run` in one window, `make run-workers` in another, and then `make integration-tests` in another.
  This uses the `database+user` isolation (see below) by default, so is a good test of how things work
  in RDS or similar.

They can also be run remotely by running `bundle exec rake release` with `RUN_INTEGRATION_TESTS_ON_RELEASE=true`.
This causes integration tests to be run as part of the release process itself.
Note that, if specs fail, this will cause the release to fail, which may not be ideal
(if not, you should run the specs as another action, after the release succeeds).

On Heroku, the integration tests are run with multiple steps (see `specs:heroku_integration_step1` for details),
so the `release` process finishes quickly and the integration tests run in a one-off dyno.

When the remote test run finishes, it will upload the test results to the database
and notify about the results in Slack (if `SLACK_WEBHOOK_URL` is configured).

## Integration with Remote Services

In order for remote webhooks to work, 3rd party services need to reach your machine.
The easiest way to do this is:

- In another tab, run ngrok, via `make ngrok` or `ngrok http -subdomain webhookdb-${USER} 18001`.
  If you don't have an ngrok subscription, that's fine, it's just a bit more work.
- Set `WEBHOOKDB_API_URL=https://webhookdb-${USER}.ngrok.io` and run the server, or run `make run-with-ngrok`
  If you have a different subdomain, use that.
- OR, you can set `WEBHOOKDB_API_URL=<whatever>` in `.env.development.local`.
- The webhook API will be reachable via ngrok. Test it with `curl https://webhookdb-${USER}.ngrok.io/healthzΩ`.

Remember you can run `export WEBHOOKDB_API_HOST=<whatever>` and then `webhookdb` CLI will use it,
or go to the `/terminal` route at your API's url, like <https://webhookdb-${USER}.ngrok.io/terminal>.

## Response Shapes

We try to avoid as much rendering logic on the client as possible.

In some cases, like for auth or querying the database,
we deal with bespoke endpoint resonse shapes.
They always have a 'message' field,
but how the response is rendered is up to the CLI.

Otherwise, there are just two response forms we care about:

- Collection responses: They always have a `display_headers` key which is an array of
  `[<item key>, <display field name>]` pairs, like `["billing_email", "Billing email"]`.
  The display headers allow custom strings and an explicit order to be used
  when we render responses.
  The collection of items are under the `items` key.
  For example: `{display_headers: [['email', 'Email']], items: [{email: 'a@b.c'}]}`.
- Single responses. Like collection responses, there is a `display_headers`,
  but each key points to a key in the root object.
  They can be rendered as a key-value list, or tabular like a single-item collection.
  For example: `{display_headers: [['email', 'Email']], email: 'a@b.c'}`.

Note most every response has a 'message' at its top level.
Usually this is displayed to the user.

## Custom Schemas

When a customer wants to change the schemas for their tables,
we do the following (see `Organization.migrate_replication_schema`):

- Use the admin connection to create the schema if it doesn't exist.
- Move the tables for all integrations into the new schema.
- Grant SELECT access on the schema to the readonly user.

Note that we do not check if a schema exists on each upsert,
since it's extra work we should not have to redo each upsert
(while we do need to ensure the table exists before we upsert a webhook).

## Migrating Organization Databases

In order to enable database migrations, you have to have the environment variable
`DB_BUILDER_ALLOW_PUBLIC_MIGRATIONS` set to true. (It defaults to false.)

To migrate databases, we need to use a zero-downtime approach,
because 1) we cannot realistically stop receiving events and have them pile up,
and 2) figuring out when it is 'safe' to cut over is very complex
(need to look at all running backfill and webhook processing jobs).

So to support migrating an organization between databases,
we take the following steps:

- Create an `Organization::DatabaseMigration`,
  storing the original and target admin URLs,
  the org schema, and the table names of all integrations.
  We need to snapshot this in case they change as we process it.
- Update the organization with the new admin and readonly urls.
- Kick off the organization database migration job.

At this point, existing jobs will write into the 'old' database, and new jobs will
start writing into the new database.

The database migration job first emails org admins about the job that is starting.
Then it iterates over all the stored tables, and all rows in those tables
and upserts them into the new database using the 'update if newer' conditional expression.
This is slower than a bulk CSV insert, but it's the only
realistic way to do the 'online' update.

The migration job processes integrations in order,
and rows in sequential order, and keeps track of its progress,
so if it fails, it can pick up where it left off
(Sidekiq will automatically retry if it errors).

Once the job finishes, we mark it as complete,
empty out the connection info,
and send an email to the organization admins.

## Organization Data Isolation

Organization data (replicated webhook/API data) can be isolated in various ways:

- **database** isolation creates a separate database per-organization.
- **schema** isolation creates a separate schema per-organization.
- **user** isolation creates a separate user per organization
  which can only be used to access that organization's data.
- **none** isolation puts every org into the public schema.

These modules and possible combinations are available as the following values:

- `database+user`
- `database+schema+user`
- `schema+user`
- `schema`
- `none`

The default isolation is `database+user`.

To set the isolation mode, set `DB_BUILDER_ISOLATION_MODE`
like `DB_BUILDER_ISOLATION_MODE=database+user`.

Which techniques can be used depends on the infrastructure WebhookDB is running on,
but the following setups are common:

- `database+user` isolation is the default isolation,
  since it is the most secure. It requires the available database connections
  in `DB_BUILDER_SERVER_URLS` (and the related `DB_BUILDER_SERVER_ENV_VARS`)
  have access to create databases and users, which is available for hosted
  DB servers like Amazon RDS, but it usually not available for hosted _databases_
  like Heroku Postgres.
- `schema` isolation provides the least isolation and is only used
  for self-hosted deployments. It allows hosting WebhookDB with a shared
  database, like in Heroku Postgres, which does not allow creation of
  databases or users via PG SQL. The connection information for every
  organization will be the same (one of the server urls).
  However, organizations can be migrated over to another database server;
  for example, some company may want to have their "production organization"
  write data directly to a primary application database,
  while the per-user and other scratch/testing orgs stay on the application database.
  - **NOTE**: WebhookDB will NOT modify default privileges for the `PUBLIC` role,
    which by default has access to the `public` schema.
    So if you want to revoke read/write access to the readonly organization user,
    which you probably do, you must run `REVOKE ALL ON SCHEMA public FROM public`
    in the relevant database.
    WebhookDB will not modify `public` access since it could break your application,
    since it would effect other users.
- `schema+user` isolation is a slight improvement over schema-only isolation.
  A user is created per-organization, so there is isolation by the read-only user
  for each organization. However, each organization's admin user will be the same
  (more precisely, one of the available server urls). This should only be used in
  self-hosted environments, and all the caveats and suggestions regarding
  schema-only isolation apply.
- `database+schema+user` isolation does not provide any meaningful
  isolation improvement over database/user isolation. It can be used if,
  you don't want organization replication tables to go into
  the `public` schema by default (note you can always move orgs from the `public` schema
  at any time using `webhookdb org migrate-schema <new-schema>`).
- `none` isolation uses the `public` schema and available server URLs verbatim,
  providing zero isolation, but is sufficient for controlled single-application use.
  Because there are no urls or schemas to worry about,
  it provides the most convenient access to your data.

## Performance Tuning

For the most part, Postgres does the bulk of the work. It's rare for WebhookDB/Ruby to be any sort of bottleneck.

Always keep the following in mind when building, and then we will talk about Postgres:

- Do bulk upserts where possible (see Plaid and Google Calendar integrations for examples).
- Use large pages (1000-2000 items) when querying external APIs where possible.
  There's no reason to use small pages in most cases.
- Make sure upserting is done on an indexed column. This is usually only an issue for bulk upserts,
  since by default row-by-row upserts use the remote column, which is always indexed.
- Index as few things as possible, since updating indices adds time to updates.
- If your replicator needs to query for things, see if you can make it an index-only scan
  (that is, an index has what the query needs). This is much faster than normal index usage
  (and obviously must never sequential scan). Again, this should be rare.
- All external calls and DB queries should have a timeout applied.

Now, for tuning Postgres. WebhookDB's 'app' database should not need any tuning;
it has pretty straightforward CRUD usage patterns with simple queries,
so there isn't much to do.

The per-organization databases may need some tuning,
especially for certain high-volume integrations. There three types of workloads you'll see:

- Single row upserts.
- Bulk upserts. These tables can be high activity, and can lead to vacuums.
- `SELECT` (by clients). Make sure these are fast, indexed queries.
  If not, indices may need to be added, or client queries may need to be adjusted.

Here are some performance tuning tips.
Some of the advice is RDS specific but should apply more broadly.

- Check out [Tuning PG](https://wiki.postgresql.org/wiki/Tuning_Your_PostgreSQL_Server)
  for some useful advice and background.
- Use `show shared_buffers` to see your shared buffers.
  It should be 25-40% of RAM. You can use this equation:
  `select (30*7.5*1024*1024 /100)/8` => `147456.000000000000`
  - 30 is 30%
  - 7.5 is 7.5 GB of RAM
  - 1024*1024 to convert GB to KB (to unify against shared_buffers units)
  - 8 is 8kB, which is what shared_buffers is set in, at least in AWS RDS.
- If performance craters, check IOPS usage. You may have exhausted your allowance.
  RDS events may let you know. Or if you see a lot of waiting on IO,
  this is usually why (check RDS Performance Insights).
  Figure out what you need to do to get more IOPS.
- If things slow down (but not crater), you may have vacuuming going on.
  Use `select * from pg_stat_activity where state != 'idle'` and see.
  If vacuuming is happening too often, your server will be slow (and especially the vacuumed tables).
  There are many ways to tune this but we need some more exploration to provide good guidance.
- Check on server load. If you're hitting CPU or memory limits, you may just need a bigger instance.

## Demo Mode

WebhookDB includes a 'demo mode' (see `demo_mode.rb` for details) that can be enabled for local installs,
such as through `docker-compose-demo.yml`.
This short-circuits auth (since emails won't work) and copies some data sets locally.

There are two parts to the demo mode:

- The server that hosts the demo data. This is generally the WebhookDB cloud production server.
  It needs a `DEMO_MODE_DEMO_ORG_ID` set to the the integration that demo data is copied from.
  Usually this integration uses 'public' data, like GitHub replicators on an open source repo.
- The 'client' webhookdb server that is asking for demo data.
  This is generally the local install.
  Custom code paths are the `/v1/auth` call (skips actual auth),
  and the `DemoModeSyncData` job (syncs data once DB is available).

### Example Datasets

Related to the Demo Mode above is enabling 'example datasets'.
Generally only WebhookDB Cloud uses this.
If enabled, it copies demo service integrations and datasets into
the default organization that is created for a user.
