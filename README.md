# Webhookdb-api

The Webhookdb API is a Ruby app using Puma (webserver), Grape (API framework),
Sequel (ORM), and Postgres (RDBMS).  

## Auth

We use a somewhat novel approach to auth to create a smooth CLI flow.

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

The tests can be run locally:

- Run `make run` in one window, `make run-workers` in another, and then `make integration-tests` in another.
  This uses the `database+user` isolation by default, so is a good test of how things work
  in RDS or similar.

Tests are also run automatically in Heroku on staging,
using the `schema` isolation since it uses a shared Heroku database.

- `RUN_INTEGRATION_TESTS_ON_RELEASE=true` is set on staging.
  This causes the `release` command to run a Rake task, `specs:integration_step1`.
  This task start a new one off dyno that runs that `specs:integration_step2`.
- `specs:integration_step2` sleeps 20 seconds and kicks off `specs:integration_step3`.
  We need this sleep to make sure that the integration test gets the newest release;
  the step2 dyno may still be using the old release.
- `specs:integration_step3` runs the integration tests in `specs:integration`.
- When the test run finishes, it will upload the test results to the database
  and notify about the results in Slack.

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
