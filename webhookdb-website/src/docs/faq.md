---
title: FAQ
path: /docs/faq
order: 30
---

We know that any partners for your business, especially ones touching data, require a huge amount of trust.
We aim to be as open and transparent as possible about how WebhookDB works.

<a id="where-is-webhookdb-built"></a>

### [Where is WebhookDB built?](#where-is-webhookdb-built)

WebhookDB is built in Portland, Oregon, USA, by the team at [Lithic Technology](https://lithic.tech).

Lithic develops custom software for all types of clients,
but especially startups (both venture-backed and bootstrapped).

Please reach out if you like what you see here, and think we can help you build your product! 

<a id="how-is-my-data-stored"></a>

### [How is my data stored?](#how-is-my-data-stored)

Right off the bat, if you are not comfortable with someone else storing data from the APIs you use,
we totally understand- please check out our [Guide to Self-Hosting WebhookDB](/docs/self-hosting)
for more information.

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

<a id="how-much-does-webhookdb-cost"></a>

### [How much does WebhookDB cost?](#how-much-does-webhookdb-cost)

Check out our [pricing page](/pricing).

<a id="never-expose-database"></a>

### [I though we should never expose a database?](#never-expose-database)

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

### [I thought services should not share schemas?](#never-share-schemas)

This advice is also generally true:
multiple microservices should not share the same database,
but instead version through requests (header, URL, etc).

However there's a simple explanation as to why
the approach WebhookDB takes is totally fine:
the schemas we expose are based on the compatibility commitments the APIs themselves are making.
For example, the Stripe Customer integration is known as `stripe_customer_v1`.
If Stripe made a backwards-incompatible change to their API,
it would no longer be their V1 API, and we'd add a `stripe_customer_v2` integration
which would carry the same compatibility guarantees as their V2 API.
