---
title: FAQ
path: /docs/faq
order: 3
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
you can rotate them from the CLI with `webhookdb `

<a id="how-much-does-webhookdb-cost"></a>

### [How much does WebhookDB cost?](#how-much-does-webhookdb-cost)

Check out our [pricing page](/pricing).
