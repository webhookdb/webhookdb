---
title: HTTP Sync
path: /docs/httpsync
order: 52
---

For most applications, being able to query data via SQL is nice, but not sufficient. You also need to know when data changes.

WebhookDB supports a new, improved, and standard paradigm for webhooks that eliminates complexity on the application developer side. (That's you!)

<a id="challenges-webhooks"></a>

### [The Challenges of Webhooks](#challenges-webhooks)

The standard pattern for webhooks is:

1. Something happens in an external system.
2. The external system sends you an event (usually they send an HTTP POST).
3. Your backend validates the event is authentic.
4. Your backend enques the event for further processing, and returns a successful response.
5. Your backend processes the event further, like synchronizing data from the external service, or updating your own data based on the external event.

The big challenge here is that the order events happen in the external system (first step), and the order your backend processes events (last step), can happen in any order. Both because events from the external system may reach your application in any order, and because your backend may not process them in serial.

So you could have, for example, have a user's name in an external system that changes from 'Kyle' to 'Taylor'; when you process these events, you either need to know which of them to throw out (this is tricky to build, and not always possible), or you need to re-query the external system for the latest data (which is potentially slow).

As an extreme case of asynchronous processing challenges, you can modify an external system inside of a database transaction, and before that transaction is committed, your backend may process the webhook it sends. This usually results in a confusing error where your backend says a resource in your database does not exist (because the transaction creating it has not committed).

<a id="challenges-polling"></a>

### [The Challenges of Polling](#challenges-polling)

This is, of course, assuming an API has solid support for webhooks. Many APIs do not. You then have to get into periodic polling. Polling has its own challenges:

- Where and how do you keep track of polling time?
- What list capabilities does the API offer? Some APIs have event logs or incremental synchronization tokens, which makes polling easier. Most do not, so you have to poll many different endpoints, not all of which can be ordered in a semantically necessary way.
- How do you handle failures, like a temporary outage, or a resource that can't be fetched? You have to try to commit what you can, when you can, so you don't end up re-iterating a list due to an error at the end.
- If you are polling often, what happens when the period polling job takes longer than its interval? Or in other words, if you poll every 60 seconds, what happens when the job takes more than 60 seconds?

<a id="httpsync-rescue"></a>

### [WebhookDB HTTP Sync to the Rescue](#httpsync-rescue)

WebhookDB's "HTTP Sync" system solves all of these issues. We've spent a lot of effort on designing an ergonomic, easy-to-use system that allows application developers to focus on logic, rather than the mechanics of handling webhooks and/or polling.

Here's how it works:

- Something happens in an external system.
- The external system sends WebhookDB an event.
- WebhookDB validates it's authentic, enqueues it for further processing, and returns a successful response.
- WebhookDB conditionally upserts this event into the database. If the event is old, then, it's discarded. If it's newer, the row gets inserted or updated.
- Every so often, or on every insert, WebhookDB sends an HTTP Sync webhook to your backend.
- Your backend validates the event is authentic.
- Your backend **synchronously processes the event** and returns a successful response.

It's important to note that *you will not need to handle concurrent HTTP Sync webhooks.*

Instead, all processing happens within your API endpoint. Your endpoint can take up to a minute (or more, when [self-hosting](/docs/self-hosting))
to respond, to make sure you have time to do what you need to with the changed data. The page size can also be modified to send fewer rows.

When your endpoint returns successfully, we assume that page has been processed, so can POST the next page, until there are no new changes. If your endpoint returns an error, we retry the POST until it succeeds.

All your endpoint has to do is process pages of rows, just like your backend would have to do. But the events will always be delivered, just once, in the order they happen (according to timestamps from their API).

In practice, this hugely simplifies handling of events. Our customers have removed hundreds or thousands of lines of code around dealing with the very uninteresting problem of handling webhooks. WebhookDB HTTP Sync frees you to focus on what's unique to your product, instead of reinventing the wheel to handle tricky webhook and polling problems.

<a id="setup"></a>

### [Setup](#setup)

HTTP Sync setup first requires you to build an endpoint in your backend that WebhookDB can reach.
This endpoint should require HTTP Basic Authentication.
These Basic Auth credentials are passed in with your backend's URL.

Once that endpoint is available, you can tell WebhookDB to sync to it: 

```arff
webhookdb httpsync create stripe_customer_v1
Enter the HTTP endpoint that WebhookDB should sync data to: https://secretuser:secretpass@api.myapplication.com 
Every 60 seconds, data from stripe_customer_v1 in stripe_customer_v1_16cd will be synchronized to https://***:***@api.myapplication.com
```

The URL that WebhookDB will HTTP Sync to:

- Must be HTTPS,
- Must contain Basic Authentication information (that's the `secretuser:secretpass@` part of the URL above),
- Must be reachable by WebhookDB.

Creating the HTTP Sync will fail if these conditions aren't met.

Once HTTP Sync is set up, it will periodically post new information to the endpoint using the interval you provided. You can also trigger a sync manually using the command `webhookdb httpsync trigger`. The response shape will contain the changed rows as they appear in our database, as well as information about the associated service integration and a timestamp for the sync:

```json
{
  "rows": [],
  "integration_id": "svi_6qsncpm12cnzjp4vkr20k62u2",
  "integration_service": "stripe_customer_v1",
  "table": "stripe_customer_v1_20f0",
  "sync_timestamp": "2017-08-30T21:12:33.000+00:00"
}
```

For a list of flags for the `webhookdb httpsync` command, pass `--help` or read the [manual](/docs/manual#httpsync).
