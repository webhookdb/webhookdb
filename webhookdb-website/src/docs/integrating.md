---
title: Integrating WebhookDB
path: /docs/integrating
order: 70
---

There are two ways you will need to access data stored in WebhookDB:
<a href="#query-access">Query Access</a>, and <a href="#notifications">Notifications</a>.
Query Access is about accessing data WebhookDB has synced,
while Notifications are about WebhookDB telling you about data changes.

<a id="query-access"></a>

# Query Access

We have a repository with some example patterns for integrating with WebhookDB.

The different patterns break down roughly as follows:

- **Use the connection string directly.** This is a great option for integrating with analytics systems,
  or where you can make independent queries against WebhookDB
  (ie, you do not need to `JOIN` or use subselects between the WebhookDB database and your own).
  It's also a good option if you aren't using Postgres otherwise;
  you can use a Postgres driver to connect to WebhookDB, no matter what your app is using.
- **Import the WebhookDB database as a Foreign Data Wrapper (FDW).**
  See [FDW below](#fdw) for more details.
  This allows you to use the WebhookDB database within another Postgres database,
  including for things like `JOIN` and subselects.
- **Use a Materialized View with the Foreign Data Wrapper.**
  See [FDW below](#fdw) for more details.
  This has all the benefits of the FDW approach,
  with the added benefit that the data sits *inside* your application's database
  in the materialized view, so it's very fast to access.
  Use this when your data can be a little bit stale (you must decide how often to refresh it),
  and/or your access patterns create problems with the FDW.
- **Write into your own database.**
  The best integration option if you have a tight coupling between your application
  and the data in WebhookDB.
  See [Bring Your Own Database](/docs/self-hosting#byod) and [Entirely Self Hosted](/docs/self-hosting#selfhosted)
  for more information.

<a id="unittests"></a>

## [WebhookDB in Unit Tests](#unittests)

Compared to using HTTP mocking, using WebhookDB for unit tests is more straightforward.
Basically, instead of mocking HTTP responses, you insert a row into a database
that your code looks for, *exactly* like fixturing data for normal application tests.

We walk through getting unit testing set up step-by-step in our
[Unit Testing Example](https://github.com/lithictech/webhookdb-demos/tree/main/unittest-rb).

<a id="fdw"></a>

## [Foreign Data Wrappers](#fdw)

Many folks that use Postgres are not familiar with Foreign Data Wrappers,
which are a pretty amazing piece of technology
that allows you to use SQL to query external databases,
including other types of database servers or another Postgres server.

We can use FDWs to import your WebhookDB database into your application database.
Please refer to our [FDW Integration Example](https://github.com/lithictech/webhookdb-demos/tree/main/app-fdw-rb)
to get see how.

The example also includes an explanation of using Materialized Views,
which will replicate the data from your WebhookDB database
directly into your own database.

<a id="notifications"></a>

# Notifications

Whenever a row changes in WebhookDB, you can be notified in one of two ways:

1. Through normal webhooks. Check out the [`webhookdb webhook` command docs](/docs/manual/#webhook) for more details.
2. Through "super webhooks", which are simple, synchronous, and resilent. This is done through the [`webhookdb sync` command](/docs/manual/#sync) command. [Read what makes these webhooks "super"](/docs/webhooks/).