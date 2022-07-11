---
title: New Paradigm for API Integration
path: /docs/api2sql
order: 25
---

When we talk about working with and integrating APIs,
we are usually talking about using JSON-over-HTTP.
In the past, and into the future,
our industries developed alternatives and improvements to JSON-over-HTTP,
like WSDL, RPC/gRPC, GraphQL, and iPaaS (Integration Platforms-as-a-Service).
Each of these solutions serve a purpose,
but none of them conquer the issues that cause API integration
to be fundamentally more complex than normal application development.

<a id="history"></a>

### Brief History of APIs

WSDL and Web Services tried to bridge the client/server divide by creating clients
in the client's native language from a declarative description (the WSDL).
But the mechanics of remote calls are so different from local processes,
and the design of these WSDL SDKs so obtuse, that I know of no programmer
who enjoys using WSDL.

RPC-based systems, especially gRPC, offer compelling performance and versioning benefits
but, as far as I know, have not seen widespread adoption outside their technical domain.
Integration with API products is not their goal, and they will likely never become
a common way to exchange data over the web.

GraphQL offers compelling benefits for remote clients (web and native apps, etc.).
But offering a public GraphQL API is rare, and developers preferring it over
a more REST-like alternative is even rarer. It requires complex and specialized tools,
and I don't see meaningful progress on using it as an API integration approach.
Recently attempts at "superschemas" have been made,
which attempt to manage the complexity of GraphQL at scale
by introducing even more complexity.

iPaaS platforms, like Zapier, Mulesoft, and dozens of others,
promise to make it easy to glue together different systems.
But while they are amazing for certain types of automation,
they introduce another whole set of problems around
maintenance, performance, security, and cost,
and so are poor fits for integrating multiple APIs.

So, we are stuck with good-ole JSON-over-HTTP, usually as some sort of REST-like API.
Just like any great, durable technology, it has a laundry list of problems,
but its simplicity and ubiquity is an undeniable asset, and not easily improved-upon.

<a id="core-problems"></a>

### Two Core Problems

No matter what you think of JSON-over-HTTP, there are two fundamental issues with it,
the three other approaches above, and pretty much any unlisted alternative.

**First: the mechanics of all APIs differ.**

The easiest example is pagination. Is it offset-based, or cursor based?
What are the parameters called? Are pages 0 or 1? What order are results returned in?

Times are another - is it an integer in seconds, or milliseconds, or is it an ISO8601 string,
with or without a timezone?

This doesn't begin to scratch the surface of the micro-differences between API schemas.
Every time you integrate an API, you have to learn the choices of the API designers.

**Second: networks are slow and unreliable.**

We expect network calls to fail, so we build in things like automatic retry.
We expect API calls to be slow, so we decouple them from our code via dependency injection.
We expect API providers to be down, so we have to build our code to be resilient against outages.

These are all absolutely necessary for a good API integration,
but it's also a high cost. On top of that, the first core problem of differing designs
spoils any chance to handle these network issues in a unified cross-API fashion.

<a id="api-over-sql"></a>

### The New Paradigm: API-over-SQL

If your API partners provided you a database connection to access your data,
you would probably use it.

You'd query the database directly, maybe throwing some read-only ORM models
in front of the tables, if you're into that.

Your access would be as fast and reliable as your application's database.
In fact, maybe the data is *stored inside your application's database.*

Instead of having to work with and around an API designer's decisions,
you can use cursor, token, or limit/offset pagination via SQL.
You wouldn't need to worry about whether some endpoints
support searching or sorting, since these are all things you can easily do with SQL.

To see the schema of the API, or inspect all its data,
you would fire up `psql` and use `\d`,
rather than trawl documentations or wrestle with Postman.

You can [secure your data with PostgreSQL permissions](/docs/securing/),
rather than handing out your API keys to every service that needs to know
anything about the data you store in APIs.
Plus, 3rd party platforms can integrate with anything
that can connect to an SQL database, rather than product-specific integrations.

This is what I call "API-over-SQL",
and in years of using the approach,
I have found it superior to JSON-over-HTTP (and other alternatives)
in every way. In fact, I continue to find new uses and benefits
as we roll this new paradigm out on a wider basis.

<a id="blockers"></a>

### Why Aren't we Using API-over-SQL?

Well, there are a couple of reasons.

First, API providers absolutely *must* offer JSON-over-HTTP.
So anything beyond that is extra work,
and if I were building an API product, I don't know that I would invest in offering
API-over-SQL since it's a pretty complex and novel offering.

Second, JSON-over-HTTP is still pretty good.
As an analogy: lots of software is still written in C,
even though superior alternatives are available for most use cases.
I suspect we'll be seeing JSON-over-HTTP for a long time.
But API-over-SQL offers compelling benefits impossible with JSON-over-HTTP,
the same way using something like Rust offers a set of benefits that are impossible with C.
For this reason, I believe we will see increased API-over-SQL adoption over time.

<a id="how-it-works"></a>

### How API-over-SQL works

It's pretty simple:

- Use a combination of webhooks, period polling, backfilling,
  and other mechanisms to get data from APIs.
- Jam that data into database tables. Normalize and index intelligently.
  Update rows carefully. Augment data that's missing from the API.
- Connect to those tables from your applications, analytics systems,
  and other parts of your business (such as no/low-code apps and automation).

There are many topics to touch on in the future,
including how this pattern scales (really well!),
versioning issues (fewer than JSON-over-HTTP!),
and data consistency (solved!). But the core of it is really just
getting 3rd party data into your own database as fast as possible,
and giving your applications a connection string.

Doing this for one API is not a huge undertaking,
if it's just for your organization's use, and the API is well-designed.
But the devil is in the details - what seems simple at first turns into
a massive undertaking. We have been developing WebhookDB for about 1.5 years,
and it is the fourth iteration of a system I've built for other companies and clients,
and we're still learning now things.

<a id="today-and-tomorrow"></a>

### API-over-SQL today (and tomorrow)

To get started with API-over-SQL today, you can try [WebhookDB](/get-started).
As far as I know, it is the only service today offering this API-over-SQL pattern.
You can use it as a hosted service, or you can self-host it and run the entire thing yourself
(see our [Guide to Self Hosting](/docs/self-hosting) for more details).
This allows you to get going quickly,
while still knowing you won't run into any performance or data governance issues later.

So yes, we're selling something, but we expect there to be other options, too,
whether home-grown, open-source, or from other companies.
We're here to support this work, and keep the conversation going.
