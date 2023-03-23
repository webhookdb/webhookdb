---
path: /blog/2023-03-cdc-everything
date: 2023-03-20T12:00:00
summary: WebhookDB allows you to add Change Data Capture to any API, no matter what. 
title: Add Change Data Capture to Any API
image: nana-smirnova-IEiAmhXehwE-unsplash.jpg
imageAlt: boxes of documents stacked in a warehouse
author: Rob Galanakis
draft: false
tags: []
---

Change Data Capture is the process of capturing changes to data
and delivering those changes in real-time to downstream systems.

Most databases support some form of CDC. Webhooks, available in many APIs,
provide a form of CDC. Many APIs, however, don't support webhooks at all,
or their support is incomplete (not available for certain types of resources,
or their delivery can be unreliable so you can miss key CDC events).

WebhookDB allows you to set up Change Data Capture for any API,
no matter what its webhooks look like.

As an extreme case, let's take an example of an API that doesn't support webhooks at all.
WebhookDB will paginate through resources and conditionally upsert only modified rows,
using the most efficient algorithm possible.
For example, many APIs have some sort of 'last modified' timestamp,
but many do not. In these cases, we add our own timestamp,
and will efficiently compare the payload and mark the row as modified only if the resource data has changed.

These modified rows are then synced to a database or HTTP endpoint as part of
WebhookDB Change Data Capture implementation (see more on [`webhookdb httpsync`](https://webhookdb.com/docs/httpsync)
and [`webhookdb dbsync`](https://webhookdb.com/docs/dbsync). You can also set up your own webhooks
to be sent from WebhookDB using [`webhookdb webhook`](https://webhookdb.com/docs/manual#webhook).

WebhookDB's CDC is so simple and flexible, you can even use it for CDC with your own application databases.
Database CDC is usually trigger, replication, or query based.
WebhookDB fits somewhere in the "query" CDC implementation.
It's dead simple to set up, with no database schema or infrastructure dependencies,
so it can be an excellent first step.

Relying on flexible, easy, and inexpensive commodity software to solve interesting problems
for the 99% of software developers is WebhookDB's bread and butter.
If you're interested in setting up Change Data Capture with WebhookDB,
[get set up with WebhookDB](/docs/guide) or [get in touch](#contact).
