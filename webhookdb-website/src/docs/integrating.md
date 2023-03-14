---
title: Integrating WebhookDB
path: /docs/integrating
order: 50
---

There are two ways you will need to access data stored in WebhookDB:
<a href="#query-access">Query Access</a>, and <a href="#notifications">Notifications</a>:

- <a href="#query-access">Query Access</a> is about accessing data WebhookDB has synced.
  You use SQL to query data from the WebhookDB database.
- <a href="#notifications">Notifications</a> are about WebhookDB telling you about data changes,
  The three options there are:
  - Your run of the mill [webhooks](/docs/manual/#webhook),
  - [HTTP Sync](/docs/httpsync), which are an improved version of traditional webhooks that
    WebhookDB sends your application for real-time processing, and
  - [DB Sync](/docs/dbsync), which syncs WebhookDB to any other database, usually for analytics and data warehouses.

<a id="query-access"></a>

# [Query Access](#query-access)

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

### [In Unit Tests](#unittests)

Compared to using HTTP mocking, using WebhookDB for unit tests is more straightforward.
Basically, instead of mocking HTTP responses, you insert a row into a database
that your code looks for, *exactly* like fixturing data for normal application tests.

We walk through getting unit testing set up step-by-step in our
[Unit Testing Example](https://github.com/lithictech/webhookdb-demos/tree/main/unittest-rb).

<a id="fdw"></a>

### [Foreign Data Wrappers](#fdw)

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

# [Notifications](#notifications)

Whenever a row changes in WebhookDB, you can be notified in any or all of the following ways:

1. Through **webhooks** which are triggered for every changed row.
   These are well-suited for asynchronous processing in your application.
   Check out how to [Proxy Webhooks](/docs/cli/#proxy-webhooks),
   and the [`webhookdb webhook`](/docs/manual/#webhook) command docs for usage.
2. Through [**HTTP Sync**](/docs/httpsync/), which is simpler, synchronous, and resilent.
   HTTP Sync is better suited for when you want to do further transformation and upserting of API data
   into your application database. WebhookDB calls your backend with pages of changed rows,
   sending additional pages only once your backend has finished processing a page.
   You never have to worry about race conditions or conflicts (a common problem with webhooks).
   This is done through the [`webhookdb httpsync`](/docs/manual/#httpsync) command.
3. Through [**DB Sync**](/docs/dbsync), which replicates data from the WebhookDB database into another database.
   This is commonly used to send data to an analytics service like Snowflake, Redshift, another Postgres, or similar.
   This requires very little setup on your side, other than sending us the connection string and target schema and table.
   This is done through the [`webhookdb dbsync`](/docs/manual/#dbsync) command.
4. There are **experimental** sync capabilities to, for example, send all rows changes to Apache Kafka or AmazonAWS SQS.
   Please get in touch if you would like this enabled for your organization.

You can mix and match these notifications. For example, each insert and update to a Stripe Customer can:

- Send a webhook to an audit logging service.
- Use HTTP Sync to send data to your application for further processing.
- Use HTTP Sync to send data to a service for online training of fraud models.
- Use DB Sync to send data to an analytics cluster.
