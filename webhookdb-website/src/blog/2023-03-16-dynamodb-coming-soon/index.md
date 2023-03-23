---
path: /blog/2023-03-dynamodb-coming-soon
date: 2023-03-16T12:00:00
summary: WebhookDB can write data to Amazon DynamoDB in addition to PostgreSQL. 
title: WebhookDB ❤️ DynamoDB
image: webhookdb-dynamodb-coming-soon.jpg
imageAlt: dynamodb and webhookdb logos
author: Rob Galanakis
draft: false
tags: []
---

#### Writing API data to DynamoDB

We at WebhookDB absolutely love PostgreSQL. But one of the problems with traditional PostgreSQL is
that you need to run it yourself. This is usually through a fully hosted single database like
Render or Heroku, a server like through AWS RDS, or running it directly on your own VMs or metal.
Running Postgres in this way means that:

- You have to pay for it even when not in use, and
- You have to scale it and manage performance.

The problem of course is that these issues compound: as you provision more resources,
you are paying more for unused time when you're not under load.

To a large degree, this can be mitigated by using serverless PostgreSQL,
like Amazon Aurora Serverless PostgreSQL-Compatible Edition.
To date, this is what we've recommended customers who are worried about scale or cost use.

Many customers however want a fully managed serverless database,
like Amazon DynamoDB. We're happy to say that WebhookDB can now write to DynamoDB.

This change should greatly reduce operational costs and complexity
for customers with WebhookDB deployed into AWS. Note this is only available for customers
self-hosting WebhookDB, or when using a publicly accessible DynamoDB endpoint.

If you're interested in storing your API data in DynamoDB,
please [let us know](#contact) so we can get you on the waitlist.
