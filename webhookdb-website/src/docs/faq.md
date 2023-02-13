---
title: FAQ
path: /docs/faq
order: 30
---

We know that any partners for your business, especially ones touching data, require a huge amount of trust.
We aim to be as open and transparent as possible about how WebhookDB works.


<a id="how-it-works"></a>

### [How does WebhookDB work?](#how-it-works)

WebhookDB is a SaaS or self-hosted service that works closely with any PostgreSQL server
to schematize, normalize, and upsert API data in real-time. We call this pattern [API2SQL](/docs/api2sql)
and we consider WebhookDB one possible implementation of API2SQL.

- WebhookDB is designed to be self-hosted, though most customers get started on the hosted SaaS version.
- WebhookDB works with any Postgres- it is *not* a managed Postgres service,
  and does not require you to run your own Postgres or install custom extensions.
- WebhookDB is designed to run worry-free. There is extensive structured logging and
  configurable error reporting for when something does go wrong.
  But things usually chug along without any issues. Our extensive unit and integration test suite
  ensures there are never regressions.

<a id="how-much-does-webhookdb-cost"></a>

### [How much does WebhookDB cost?](#how-much-does-webhookdb-cost)

Check out our [pricing page](/pricing).

Our standard licensing model is a yearly flat fee for a self-hosted version,
with unlimited hosted version use while you get set up.
If you're not sure if you can afford it, it doesn't hurt to ask-
as a bootstrapped company, we're usually able to make it work for smaller orgs
and non-profits.

<a id="build-it-myself"></a>

### [Why shouldn't I build this myself?](#build-it-myself)

This is a question we get a lot. We definitely ask it whenever someone tries to sell us any technology!

We could give examples of the thousands of things you end up needing to think about
integrating APIs, like processing out-of-order webhooks, backfilling, and verification.

Instead, we'll compare WebhookDB to infrastructure abstraction, using AWS as an example.

Let's say you want to run a web application in a container.
You can run your own hardware (no AWS); or you can manage your own VMs (EC2);
or you can run orchestration (ECS); or you can just have a way to run requests
without worrying about how it's done (Lambda).

While there *are* reasons for each option, and you could end up building your own Lambda service,
why not just use what's off the shelf? After all, you just want to run the application and serve requests.

This is basically the same thing for WebhookDB. We're the 'AWS Lambda' of API integration.

Integrating with APIs is (or should be) a commodity problem.
The fact that each one paginates differently, for example, isn't interesting; why should you have to care?

Just like your organization doesn't create value from building your own Lambda,
you don't create value re-solving an API integration problem over and over.
You can just pay someone who has already solved it and re-use that solution.

<a id="how-is-my-data-stored"></a>

### [How is my data stored in the hosted SaaS version?](#how-is-my-data-stored)

**Note: This applies only to the fully-hosted SaaS version of WebhookDB.
Paying customers can and should use self-hosting, in which case,
all data stays entirely under your control.
For more information about self-hosting, check out our
[Guide to Self-Hosting WebhookDB](/docs/self-hosting).**

All of your data is stored encrypted in Postgres databases in Amazon Web Services.

The data for each organization is stored in a separate database.

All reads and writes to your organizations data are done through extremely narrow Postgres roles.
The connection string you get for your database can only read your tables.

The web-facing application itself cannot read or write to your data tables,
though it does have access to your connection strings.
However those strings are encrypted at the column level
with a regularly rotated key,
so even if you had a copy of the production database you would not be able
to access the connection strings.

If your connection strings ever become compromised,
you can rotate them from the CLI with `webhookdb db roll-credentials`.

<a id="never-expose-database"></a>

### [I though we should never expose a database?](#never-expose-database)

**Note: This applies only to the fully-hosted SaaS version of WebhookDB.
Paying customers can and should use self-hosting, in which case,
all data stays entirely under your control.
For more information about self-hosting, check out our
[Guide to Self-Hosting WebhookDB](/docs/self-hosting).**

This advice is generally true, but WebhookDB has two things going for it.

First, managing user access is a core concern, similar to something like shared database hosting.
There's nothing conceptually wrong with exposing your database to the public;
it's just that the failure mode can be catastrophic so you should avoid it
unless you know what you're doing.

Second, if you still don't feel good about it,
you can [self-host WebhookDB](/docs/self-hosting) so it sits in your VPC.
You can then implement your own endpoint,
using your access control, to access WebhookDB.

[See more about securing WebhookDB](/docs/securing/).

<a id="never-share-schemas"></a>

### [I thought services should not share database schemas?](#never-share-schemas)

This advice is also generally true:
multiple microservices should not share the same database,
but instead version through requests (header, URL, protobuf, etc).

However there's a simple explanation as to why
the approach WebhookDB takes is totally fine:
the schemas we expose are based on the compatibility commitments the APIs themselves are making.
For example, the Stripe Customer integration is known as `stripe_customer_v1`.
If Stripe made a backwards-incompatible change to their API,
it would no longer be their V1 API, and we'd add a `stripe_customer_v2` integration
which would carry the same compatibility guarantees as their V2 API.

<a id="where-is-webhookdb-built"></a>

### [Where is WebhookDB built?](#where-is-webhookdb-built)

WebhookDB is built in Portland, Oregon, USA, by the team at [Lithic Technology](https://lithic.tech).
