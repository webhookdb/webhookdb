---
path: /blog/2023-03-webhookdb-kafka
date: 2023-03-09T12:00:00
summary: I'm not saying you can use WebhookDB instead of Kafka, but you (probably) can use WebhookDB instead of Kafka. 
title: Do you need Kafka?
image: susan-q-yin-Ctaj_HCqW84-unsplash.jpg
imageAlt: kafkaesque maze
author: Rob Galanakis
draft: false
tags: []
---

#### I'm not saying you can use WebhookDB instead of Kafka...

...but you (probably) can use WebhookDB instead of Kafka.

<div class="text-center mt-2 mb-4">
<img src="/content/blog/thumbnail/kafka-webhookdb-ancient-aliens-nocrop.jpg" alt="Giorgio Touskalos, the ancient aliens guy"></img>
</div>

Apache Kafka is a powerful technology that is all about ingesting and directing
massive streams of events between nearly any type of data sources.
It's flexible and powerful and, at large enterprises, almost everywhere
(they claim 80% of Fortune 100 companies use Kafka).

If you squint, a whole lot of problems fall into this domain,
which is one reason Kafka is so popular.

Unfortunately, Kafka is notoriously difficult to run,
and despite the flexibility of what it can be used for,
can't really be used _by itself_ for very much.

That's sort of the point: Kafka connects together the parts of your stack that are actually valuable.
In most cases that means the applications and services generating events,
and the data warehouse that collects them.

#### Do you actually need Kafka?

Kafka is, for most use cases, purely added complexity.
It's a bear to operate and integrate with and can be a big distraction
from the work most application and product companies are doing.

If your Kafka pipeline is the common case &mdash; sending events from
your applications to a warehouse &mdash; what if I told you commodity databases
like PostgreSQL eliminate the need for Kafka?

If you're handling a sustained load of less than, say, 20,000 events per second,
you can almost definitely run your pipeline through WebhookDB.
It's not quite the same conceptually, since WebhookDB is not usually dealing with events (though it can).
Instead, it's writing the events safely to Postgres (and soon, DynamoDB),
and from there changes can be efficiently staged and sent to your data warehouse.

WebhookDB gives you nearly all the benefits of Kafka for the common use case, without the headaches and complexity.

If you're thinking of scratching an itch with Kafka, you should take a look at WebhookDB.
[Give WebhookDB a try](/docs/guide) or [let us know what you think](#contact).
