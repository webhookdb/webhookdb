---
path: /blog/2023-03-why-webhookdb
date: 2023-03-20T12:00:00
summary: Announcing WebhookDB. Store data from any API in Postgres, and query it in real-time.
title: Why WebhookDB?
image: ivan-diaz-uW39J-CzwNs-unsplash.jpg
imageAlt: whale jumping from the ocean
author: Rob Galanakis
draft: false
tags: []
---

#### Have you ever wanted to use SQL to ask an API a question?

Our guess is that you have. This is the crux of the reason we built WebhookDB.
Rather than being hidden behind proprietary APIs, we wanted to be able to use SQL to query any API.
It was also vital that the answers served are absolutely correct, incredibly fast, and worked for any API.

WebhookDB is, as far as we know, unique in that **nothing else on the market allows you to do get correct and fast results.**
And it's certainly the only one that can work on literally any API (yes, even that one you're thinking it can't handle).

It turns out that getting fast and correct answers to SQL queries against any API has a whole bunch of benefits.
So many, in fact, that it opens up programming approaches that drastically simplify your code.

In future blog posts we'll get into more concrete WebhookDB use cases.
For now, just imagine if you could search and paginate easily,
even across multiple resources and endpoints; if queries were as fast as a database;
if you didn't have to worry about availability; if you always had correct types,
like timestamps with timezones instead of strings; and if you could do this for any API,
using technology you can easily host and run, rather than paying some monthly SaaS subscription.

If you can imagine this, you'd know why dozens of companies large and small,
new and established, have jumped on the WebhookDB wagon.
[Give WebhookDB a try](/docs/guide) or [let us know what you think](#contact).
