---
title: Self Hosting
path: /docs/self-hosting
order: 40
---

There are three ways you can work with WebhookDB:

<a id="hosted"></a>

## [Entirely hosted](#hosted)

We run everything.

- Webhooks are sent to our servers.
- Any API keys you provide are stored in our application database.
- The data we store on your behalf sits on one of our shared database servers.
- We maintain the database users and hosts (you only have read-only access).

Pricing for our hosted service is found on our [Pricing Page](/pricing).
As long as you are comfortable with the data storage situation,
we recommend our hosted service, since it requires no work on your part.

In order to integrate the WebhookDB database and your own databases,
you can use the connection string directly,
or set up Foreign Data Wrappers (and optionally, Materialized Views)
as per the [Integration Guide](/docs/integrating#fdw).

<a id="byod"></a>

## [Bring Your Own Database](#byod)

We run the servers, but you provide the database.

- Webhooks are sent to our servers.
- Any API keys you provide are stored in our application database.
- *We write all API data to your database.* We still store some data for our job and retry system,
  but everything else resides in your database. You provide us a connection with
  write access to a particular database or schema.

Our "bring your own database" (BYOD) setup is most useful for customers
who deal with either huge amounts of data, cannot integrate via Foreign Data Wrappers,
or feel more comfortable with data sitting on their servers.

We do not yet offer self-serve BYOD setup,
since it requires you provision a database user with the right permissions,
and can be tricky to get right.
Please email <a href="mailto:webhokdb@lithic.tech">webhookdb@lithic.tech</a>
if you would like to get set up with BYOD.
In the meantime, you can set up a hosted version and we can migrate
to your database when you're ready.

<a id="selfhosted"></a>

## [Entirely Self-Hosted](#selfhosted)

You run it all.

- We give you a Docker container and instructions on running the app.
- Requires something that can run containers (ECS, GKE, Heroku, etc),
  plus a PostgresQL database and Redis database.
- Very flexible with where your API data is written,
  so you don't need to provision extra database servers if you don't want.
  We support everything from a dedicated Postgres server (like AWS RDS)
  to shared Postgres hosting (like Heroku Posgres), and all combinations
  in between.

This gives you total ownership over everything that goes on.
We're here for support!

The self-hosted option is only available for Enterprise customers.
Please email <a href="mailto:webhokdb@lithic.tech">webhookdb@lithic.tech</a>
to get that conversation started.
