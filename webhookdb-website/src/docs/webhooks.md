---
title: Super Webhooks
path: /docs/webhooks
order: 80
---

For most applications, being able to query data via SQL is nice, but not sufficient. You also need to know when data changes.

WebhookDB supports a new, improved, and standard paradigm for webhooks that eliminates complexity on the application developer side. (That's you!)

### The Problems with Webhooks

The problem with webhooks are that they are asynchronous. You (hopefully) get an HTTP POST from an API.
Then you enqueue something that should happen. And at some point, it (hopefully) does.

There are some big problems here that lead to complexity and bugs on the application side. Webhooks can be received out of order, or they can be processed out of order by your backend. You can receive the webhook before the database transaction that caused it has even committed to your database. And perhaps the most frustrating: lots of APIs and resources within APIs do not support webhooks, or support them in very confusing or non-standard ways.

### Super Webhooks to the Rescue

Super Webhooks solve all of these issues. Because of our commitment to fostering new paradigms using simple technology and concepts, the design is elegant and easy to use.

**Super Webhooks POST pages of changed resources to an endpoint.** When your endpoint returns, we assume that page has been processed,
so can POST the next page, until there are no new changes. If your endpoint returns an error,
we retry the POST.

All your endpoint has to do is process pages of rows,
just like your backend would have to do. But the events will always be delivered, just once,
in the order they happen (according to timestamps from their API).

In practice, this hugely simplifies handling of events. Our customers have removed hundreds or thousands of lines of code
around dealing with the very uninteresting problem of handling webhooks.
Super webhooks free you to focus on what's unique to your product, instead of reinventing the wheel to handle tricky webhook problems.

It's easy to get set up with Super Webhooks. Once you have an integration set up,
run [`webhookdb superhook`](/docs/manual/#superhook) to start setting up your Super Webhook.

(*Note: this feature is in beta, please email us <a href="mailto:hello@webhookdb.com">hello@webhookdb.com</a>
if you want to give it a spin.*)
