---
title: Manual
path: /docs/manual
order: 30
---
All commands for the WebhookDB CLI.

```toc
```

<a id="name"></a>

## [Name](#name)

webhookdb - CLI for the WebhookDB (https://webhookdb.com) application. WebhookDB allows you
to query any API in real-time with SQL.

To create an account and get started, run:

```arff
webhookdb auth login
```
The CLI will guide you from there.

The CLI also gives you quick access to the WebhookDB documentation:

```arff
webhookdb docs html
webhookdb docs tui
```

<a id="synopsis"></a>

## [Synopsis](#synopsis)

webhookdb

```arff
[--debug]
[--help|-h]
[--quiet|-q]
```

**Usage**:

```arff
webhookdb [GLOBAL OPTIONS] command [COMMAND OPTIONS] [ARGUMENTS...]
```

<a id="global-options"></a>

## [Global Options](#global-options)

**--debug**: 

**--help, -h**: show help

**--quiet, -q**: Do not print messages. Mostly used for collection endpoints, where you just want the returned data, not the help message.


<a id="commands"></a>

## [Commands](#commands)

<a id="auth"></a>

### [auth](#auth)

These commands control the auth process.

<a id="whoami"></a>

#### [whoami](#whoami)

Print information about the current user.

**--format, -f**="": Format of the output. One of: json, csv, table, raw (default: table)

<a id="login,-signup,-signin,-register"></a>

#### [login, signup, signin, register](#login,-signup,-signin,-register)

Sign up or log in.

**--token, -t**="": One-time-password token received in your email after running 'auth login'.

**--username, -u, --email**="": Takes an email.

<a id="logout"></a>

#### [logout](#logout)

Log out of your current session.

**--remove, -r**: If given, remove all WebhookDB preferences.

<a id="backfill"></a>

### [backfill](#backfill)

Start backfilling all the resources available to the service integration.

**--integration, -i**="": Integration identifier. This can either be the service name, the table name, or the opaque id, which is a unique code that starts with 'svi_'. Run webhookdb integrations list to see a list of all your integrations.

**--org, -o**="": Takes an org key. Run `webhook org list` to see a list of all your org keys.

<a id="reset"></a>

#### [reset](#reset)

Reset any stored API keys and secrets associated with backfilling this integration.

**--org, -o**="": Takes an org key. Run `webhook org list` to see a list of all your org keys.

<a id="db"></a>

### [db](#db)

Command namespace for interacting with your organization's database and tables.

<a id="connection"></a>

#### [connection](#connection)

Print the database connection url for an organization.

**--org, -o**="": Takes an org key. Run `webhook org list` to see a list of all your org keys.

<a id="tables"></a>

#### [tables](#tables)

List all tables in an organization's database.

**--org, -o**="": Takes an org key. Run `webhook org list` to see a list of all your org keys.

<a id="sql"></a>

#### [sql](#sql)

Execute query on organization's database.

**--color, -c**: Display colors. Default true if tty.

**--org, -o**="": Takes an org key. Run `webhook org list` to see a list of all your org keys.

**--query, -u**="": Query string to execute using your connection.

<a id="roll-credentials"></a>

#### [roll-credentials](#roll-credentials)

Roll the credentials for an organization's database to something newly randomly generated.

**--org, -o**="": Takes an org key. Run `webhook org list` to see a list of all your org keys.

<a id="fdw"></a>

#### [fdw](#fdw)

Write out commands that can be used to generate a FDW against your WebhookDB database and import them into materialized views. See flags for further usage.

**--all**: Write a single SQL statement containing FDW and view creation code. Default if neither --fdw or --views are passed.

**--fdw**: Write the FDW SQL to stdout

**--fetch**="": fetch_size option used during server creation (default: 50000)

**--into-schema**="": Name of the schema to import the remote tables into (in `IMPORT FOREIGN SCHEMA public INTO <into schema>` call). (default: webhookdb_remote)

**--org, -o**="": Takes an org key. Run `webhook org list` to see a list of all your org keys.

**--raw**: If given, print the raw SQL returned from the server. Useful if you want to pipe through jq or something similar.

**--remote**="": The remote server name, used in the `CREATE SERVER <remote>` call (default: webhookdb_remote)

**--views**: Write the SQL to create the materialized views to stdout

**--views-schema**="": Create materialized views in this schema. You can use 'public' if you do not want to qualify webhookdb tables. (default: webhookdb)

<a id="rename-table"></a>

#### [rename-table](#rename-table)

Rename the database table associated with the integration.

**--integration, -i**="": Integration identifier. This can either be the service name, the table name, or the opaque id, which is a unique code that starts with 'svi_'. Run webhookdb integrations list to see a list of all your integrations.

**--new-name, -n**="": The new name of the table. Valid table names must adhere to the following rules: must begin with an ASCII letter, contain only ASCII letters, numbers, underscores, dashes, and spaces, can begin and end with double quotes, and must otherwise be a valid Postgres identifier.

**--org, -o**="": Takes an org key. Run `webhook org list` to see a list of all your org keys.

<a id="migrations"></a>

#### [migrations](#migrations)

Command namespace for interacting with your organizations database migrations.

<a id="start"></a>

##### [start](#start)

Enqueue a migration of all your organization's data to a new database.

**--admin-url, -a**="": 

**--org, -o**="": Takes an org key. Run `webhook org list` to see a list of all your org keys.

**--readonly-url, -r**="": 

<a id="list"></a>

##### [list](#list)

List all database migrations.

**--format, -f**="": Format of the output. One of: json, csv, table, raw (default: table)

**--org, -o**="": Takes an org key. Run `webhook org list` to see a list of all your org keys.

<a id="docs"></a>

### [docs](#docs)

Work with the WebhookDB docs and guide.

<a id="html"></a>

#### [html](#html)

Open a browser to the WebhookDB HTML guide.

<a id="tui"></a>

#### [tui](#tui)

Render the WebhookDB guide into a local Markdown viewer.

**--org, -o**="": Takes an org key. Run `webhook org list` to see a list of all your org keys.

<a id="build"></a>

#### [build](#build)

Build the docs for the app.

**--format**="": One of: markdown, man

**--help, -h**: show help

<a id="fixtures"></a>

### [fixtures](#fixtures)

Output the SQL DDL (CREATE TABLE command) to create a DB table that matches what is in WebhookDB. This can be used to generate .sql files that can be run as part of test database fixturing.

**--service, -s**="": Name of the service. Run `webhookdb services list` to see a list of all services available to your organization.

<a id="integrations,-integration"></a>

### [integrations, integration](#integrations,-integration)

Make sure that you're working on the correct organization when you create an integration.

<a id="create"></a>

#### [create](#create)

Create an integration for the given organization.

**--confirm, -c**: If there is already an integration for this service, you will be prompted to confirm you want to create a new integration. Pass --confirm to automatically accept this prompt and always create a new integration.

**--org, -o**="": Takes an org key. Run `webhook org list` to see a list of all your org keys.

**--service, -s**="": Name of the service. Run `webhookdb services list` to see a list of all services available to your organization.

<a id="delete"></a>

#### [delete](#delete)

Delete an integration and its table.

**--confirm, -c**="": Confirm this action by providing a value of the integration's table name. Will be prompted if not provided.

**--integration, -i**="": Integration identifier. This can either be the service name, the table name, or the opaque id, which is a unique code that starts with 'svi_'. Run webhookdb integrations list to see a list of all your integrations.

**--org, -o**="": Takes an org key. Run `webhook org list` to see a list of all your org keys.

<a id="info"></a>

#### [info](#info)

Display information about given integration.

**--field, -f**="": The field that you want information about.

**--integration, -i**="": Integration identifier. This can either be the service name, the table name, or the opaque id, which is a unique code that starts with 'svi_'. Run webhookdb integrations list to see a list of all your integrations.

**--org, -o**="": Takes an org key. Run `webhook org list` to see a list of all your org keys.

<a id="list"></a>

#### [list](#list)

List all integrations for the given organization.

**--format, -f**="": Format of the output. One of: json, csv, table, raw (default: table)

**--org, -o**="": Takes an org key. Run `webhook org list` to see a list of all your org keys.

<a id="reset"></a>

#### [reset](#reset)

Reset the webhook secret for this integration.

**--integration, -i**="": Integration identifier. This can either be the service name, the table name, or the opaque id, which is a unique code that starts with 'svi_'. Run webhookdb integrations list to see a list of all your integrations.

**--org, -o**="": Takes an org key. Run `webhook org list` to see a list of all your org keys.

<a id="stats"></a>

#### [stats](#stats)

Get statistics about webhooks for this integration.

**--format, -f**="": Format of the output. One of: json, csv, table, raw (default: table)

**--integration, -i**="": Integration identifier. This can either be the service name, the table name, or the opaque id, which is a unique code that starts with 'svi_'. Run webhookdb integrations list to see a list of all your integrations.

**--org, -o**="": Takes an org key. Run `webhook org list` to see a list of all your org keys.

<a id="org,-orgs,-organization,-organizations"></a>

### [org, orgs, organization, organizations](#org,-orgs,-organization,-organizations)

Create and activate an organization, invite new members, and change membership roles.

<a id="activate"></a>

#### [activate](#activate)

Change the default organization for any command you run.

**--org, -o**="": Takes an org key. Run `webhook org list` to see a list of all your org keys.

<a id="changerole,-change-role"></a>

#### [changerole, change-role](#changerole,-change-role)

Change the role of members of your organization.

**--role, -r**="": Role name, like 'member' or 'admin'.

**--usernames**="": Takes multiple emails.

<a id="close"></a>

#### [close](#close)

Close down this organization.

**--org, -o**="": Takes an org key. Run `webhook org list` to see a list of all your org keys.

<a id="create"></a>

#### [create](#create)

Create and activate an organization.

**--name, -n**="": Name of the new organization. The unique key for the org is derived from this name.

<a id="invite"></a>

#### [invite](#invite)

Invite a user to your organization.

**--org, -o**="": Takes an org key. Run `webhook org list` to see a list of all your org keys.

**--role, -r**="": Role to assign the new organization member

**--username, -u, --email**="": Takes an email.

<a id="join"></a>

#### [join](#join)

Join an organization using a join code. You can also see your pending invites with `webhookdb org list`.

**--code, -c**="": Invitation code sent to the new member. Has 'join-' prefix.

<a id="list"></a>

#### [list](#list)

List all organizations that you are a member of.

<a id="current"></a>

#### [current](#current)

Display the name and slug of the currently active organization.

<a id="members"></a>

#### [members](#members)

List all members of the given organization.

**--format, -f**="": Format of the output. One of: json, csv, table, raw (default: table)

**--org, -o**="": Takes an org key. Run `webhook org list` to see a list of all your org keys.

<a id="remove"></a>

#### [remove](#remove)

Remove a member from an organization.

**--org, -o**="": Takes an org key. Run `webhook org list` to see a list of all your org keys.

**--username, -u, --email**="": Takes an email.

<a id="update"></a>

#### [update](#update)

Change the name or billing email of the organization. (Note: the org key is immutable and will not change.)

**--field, -f**="": The field that you want to change.

**--org, -o**="": Takes an org key. Run `webhook org list` to see a list of all your org keys.

**--value, -v**="": The new value for the chosen field

<a id="services,-service"></a>

### [services, service](#services,-service)

Work with available services that can be hooked up to reflect data to WebhookDB.

<a id="list"></a>

#### [list](#list)

List all available services.

**--format, -f**="": Format of the output. One of: json, csv, table, raw (default: table)

**--org, -o**="": Takes an org key. Run `webhook org list` to see a list of all your org keys.

<a id="subscription,-subscriptions,-sub,-subs"></a>

### [subscription, subscriptions, sub, subs](#subscription,-subscriptions,-sub,-subs)

Work with your WebhookDB subscription.

<a id="info"></a>

#### [info](#info)

Get information about an organization's software subscription.

**--format, -f**="": Format of the output. One of: json, csv, table, raw (default: table)

**--org, -o**="": Takes an org key. Run `webhook org list` to see a list of all your org keys.

<a id="edit"></a>

#### [edit](#edit)

Open stripe portal to edit subscription.

**--org, -o**="": Takes an org key. Run `webhook org list` to see a list of all your org keys.

**--plan, -p**="": Plan name, like 'yearly', 'monthly', etc. Use `webhookdb subscription plans` to see available plans.

<a id="plans"></a>

#### [plans](#plans)

Print information about the WebhookDB pricing plans.

**--format, -f**="": Format of the output. One of: json, csv, table, raw (default: table)

**--org, -o**="": Takes an org key. Run `webhook org list` to see a list of all your org keys.

<a id="dbsync,-sync"></a>

### [dbsync, sync](#dbsync,-sync)

Replicate data in a WebhookDB table to another database.

<a id="create"></a>

#### [create](#create)

Create a database sync target for the specified integration. Data will be automatically synced from the integration's WebhookDB table into the database specified by the connection string. PostgresQL and SnowflakeDB databases are supported.

**--connection-url, -u**="": The connection string for the database that WebhookDB should write data to.

**--integration, -i**="": Integration identifier. This can either be the service name, the table name, or the opaque id, which is a unique code that starts with 'svi_'. Run webhookdb integrations list to see a list of all your integrations.

**--org, -o**="": Takes an org key. Run `webhook org list` to see a list of all your org keys.

**--period**="": Number of seconds between syncs. (default: 0)

**--schema**="": Schema (or namespace) to write the table into. Default to no schema/namespace.

**--table**="": Table to create and update. Default to match the table name of the service integration.

<a id="delete"></a>

#### [delete](#delete)

Delete the database sync target and stop any further syncing. The database being synced to is not modified.

**--org, -o**="": Takes an org key. Run `webhook org list` to see a list of all your org keys.

**--target, -t**="": Sync target opaque id. Use `webhookdb dbsync list` to see a list of all your database sync targets.

<a id="list"></a>

#### [list](#list)

List all database sync targets for the given organization.

**--format, -f**="": Format of the output. One of: json, csv, table, raw (default: table)

**--org, -o**="": Takes an org key. Run `webhook org list` to see a list of all your org keys.

<a id="update"></a>

#### [update](#update)

Update the database sync target. Use `webhookdb dbsync list` to see all database sync targets.

**--org, -o**="": Takes an org key. Run `webhook org list` to see a list of all your org keys.

**--period**="": Number of seconds between syncs. (default: 0)

**--schema**="": Schema (or namespace) to write the table into. Default to no schema/namespace.

**--table**="": Table to create and update. Default to match the table name of the service integration.

**--target, -t**="": Sync target opaque id. Use `webhookdb dbsync list` to see a list of all your database sync targets.

<a id="update-creds"></a>

#### [update-creds](#update-creds)

Update the username and password used to connect to the database being synced to.

**--org, -o**="": Takes an org key. Run `webhook org list` to see a list of all your org keys.

**--password, -p**="": Takes a password.

**--target, -t**="": Sync target opaque id. Use `webhookdb dbsync list` to see a list of all your database sync targets.

**--user, -u**="": Takes a username.

<a id="trigger"></a>

#### [trigger](#trigger)

Trigger a database sync to the sync target. The database sync will happen at the earliest possible moment since the last sync, no matter how long the configured period is on the sync target.

**--org, -o**="": Takes an org key. Run `webhook org list` to see a list of all your org keys.

**--target, -t**="": Sync target opaque id. Use `webhookdb dbsync list` to see a list of all your database sync targets.

<a id="httpsync"></a>

### [httpsync](#httpsync)

Replicate data in a WebhookDB table to another http endpoint.

<a id="create"></a>

#### [create](#create)

Create a http sync target for the specified integration. Data will be automatically synced from the integration's WebhookDB table into the http endpoint specified by the connection string. Only https urls are supported.

**--connection-url, -u**="": The connection string for the http endpoint that WebhookDB should write data to.

**--integration, -i**="": Integration identifier. This can either be the service name, the table name, or the opaque id, which is a unique code that starts with 'svi_'. Run webhookdb integrations list to see a list of all your integrations.

**--org, -o**="": Takes an org key. Run `webhook org list` to see a list of all your org keys.

**--pagesize**="": Max number of rows WebhookDB sends the sync target in each call. (default: 0)

**--period**="": Number of seconds between syncs. (default: 0)

<a id="delete"></a>

#### [delete](#delete)

Delete the http sync target and stop any further syncing. The http endpoint being synced to is not modified.

**--org, -o**="": Takes an org key. Run `webhook org list` to see a list of all your org keys.

**--target, -t**="": Sync target opaque id. Use `webhookdb httpsync list` to see a list of all your http sync targets.

<a id="list"></a>

#### [list](#list)

List all http sync targets for the given organization.

**--format, -f**="": Format of the output. One of: json, csv, table, raw (default: table)

**--org, -o**="": Takes an org key. Run `webhook org list` to see a list of all your org keys.

<a id="update"></a>

#### [update](#update)

Update the http sync target. Use `webhookdb httpsync list` to see all http sync targets.

**--org, -o**="": Takes an org key. Run `webhook org list` to see a list of all your org keys.

**--pagesize**="": Max number of rows WebhookDB sends the sync target in each call. (default: 0)

**--period**="": Number of seconds between syncs. (default: 0)

**--target, -t**="": Sync target opaque id. Use `webhookdb httpsync list` to see a list of all your http sync targets.

<a id="update-creds"></a>

#### [update-creds](#update-creds)

Update the username and password used to connect to the http endpoint being synced to.

**--org, -o**="": Takes an org key. Run `webhook org list` to see a list of all your org keys.

**--password, -p**="": Takes a password.

**--target, -t**="": Sync target opaque id. Use `webhookdb httpsync list` to see a list of all your http sync targets.

**--user, -u**="": Takes a username.

<a id="trigger"></a>

#### [trigger](#trigger)

Trigger a http sync to the sync target. The http sync will happen at the earliest possible moment since the last sync, no matter how long the configured period is on the sync target.

**--org, -o**="": Takes an org key. Run `webhook org list` to see a list of all your org keys.

**--target, -t**="": Sync target opaque id. Use `webhookdb httpsync list` to see a list of all your http sync targets.

<a id="update,-upgrade"></a>

### [update, upgrade](#update,-upgrade)

Update the version of the CLI in-place.

**--path**="": Download the new version to the given path. Default to the current executable.

**--version**="": Use a specific version rather than latest. Can be used to downgrade.

<a id="webhook,-webhooks"></a>

### [webhook, webhooks](#webhook,-webhooks)

Manage webhooks that will be notified when WebhookDB data is updated.

<a id="create"></a>

#### [create](#create)

Create a new webhook that WebhookDB will call on every data update.

**--integration, -i**="": Integration identifier. This can either be the service name, the table name, or the opaque id, which is a unique code that starts with 'svi_'. Run webhookdb integrations list to see a list of all your integrations.

**--org, -o**="": Takes an org key. Run `webhook org list` to see a list of all your org keys.

**--secret**="": Random secure secret to use to sign webhooks coming from WebhookDB.

**--url**="": Full URL to the endpoint that will be POSTed to whenever this organization or integration is updated.

<a id="list"></a>

#### [list](#list)

List all created webhooks.

**--format, -f**="": Format of the output. One of: json, csv, table, raw (default: table)

**--org, -o**="": Takes an org key. Run `webhook org list` to see a list of all your org keys.

<a id="test"></a>

#### [test](#test)

Send a test event to webhook subscription with the given ID.

**--webhook, -w**="": Webhook opaque id. Run `webhookdb webhook list` to see a list of all your webhooks.

<a id="delete"></a>

#### [delete](#delete)

Delete this webhook subscription, so no future events will be sent.

**--webhook, -w**="": Webhook opaque id. Run `webhookdb webhook list` to see a list of all your webhooks.

<a id="version"></a>

### [version](#version)

Print version and exit.

<a id="help,-h"></a>

### [help, h](#help,-h)

Shows a list of commands or help for one command
