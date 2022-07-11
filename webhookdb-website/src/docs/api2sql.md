---
title: API2SQL - New Paradigm for API Integration
path: /docs/api2sql
order: 25
---

When we talk about working with and integrating APIs,
we are usually talking about HTTP-based (or custom protocol) network calls.
These come in many flavors: most notably, REST (or more generally, JSON-over-HTTP),
but also GraphQL, WSDL, RPC/gRPC, and iPaaS (Integration Platforms-as-a-Service).
Each of these solutions serve a purpose,
but none of them conquer the issues that cause API integration
to be fundamentally more complex than normal application development.

<a id="hard-problem"></a>

### The Problem of API Integration

Before going further, we should better define the scope of the problem.
"How do two computers communicate" is a general problem with many solutions,
and no single technology is going to be suitable.

When we're discussing **API Integration**, however, the problem isn't so general.
API integration, as we'll define it, involves:

- **Distributed state.** Your system has some identifier for resources in the API.
  You may copy that state into your database, but it isn't authoritative.
- **Mutating external state.** This may be done with HTTP verbs with REST,
  a Mutation in GraphQL, etc.
- **Querying external state.** Your system has mechanisms to query the state of collections
  of resources and individual resources (using their identifier).
- **Heterogenous access.** This is the *key* difference between general distributed systems
  and API integration. Most APIs will have different patterns for authentication,
  authorization, and querying; different performance and uptime characteristics;
  use entirely different protocols for communication; and vary along pretty much any other vector.

With this scope of the problem framed, let's look at the current solutions,
what is holding us back, and a new way forward.

<a id="history"></a>

### Brief History of APIs

The development of API technology is one of incremental innovation.

[RPC-based systems](https://en.wikipedia.org/wiki/Remote_procedure_call),
especially [gRPC](https://en.wikipedia.org/wiki/GRPC),
offer compelling performance and versioning benefits but,
as far as we know, have not seen widespread adoption outside their technical domain.
It is designed primarily for use within services designed to work together.
Integration with API products is not their goal, and they will likely never become
a common way to exchange data over the web.

[WSDL and Web Services](https://en.wikipedia.org/wiki/Web_Services_Description_Language)
tried to bridge the client/server divide by creating SDKs
in the client's native language from a declarative description (the WSDL).
But the mechanics of remote calls are so different from local processes,
and the design of these WSDL SDKs so obtuse, that we know of no programmer
who enjoys using WSDL.

[REST](https://en.wikipedia.org/wiki/Representational_state_transfer)
doesn't need much of an introduction. It's easy to set up,
and easy to use. The downsides, likewise, are well-known:
there is no standardization, APIs are often lacking, HTTP calls are
slow and brittle, etc.

[GraphQL](https://en.wikipedia.org/wiki/GraphQL)
offers compelling benefits for remote clients (web and native apps, etc.).
But offering a public GraphQL API is rare, and developers preferring it over
a more REST-like alternative is even rarer. It requires complex and specialized tools,
and hasn't seen meaningful progress on using it for API integration.
Recently attempts at "superschemas" have been made,
which is useful for services part of the same larger system (like RPC);
though sadly, superschemas manage the complexity of GraphQL at scale
by introducing even more complexity.

[IPaaS platforms](https://en.wikipedia.org/wiki/Cloud-based_integration),
like Zapier, Mulesoft, and dozens of others,
promise to make it easy to glue together different systems.
But while they are amazing for certain types of automation,
they introduce another whole set of problems around
maintenance, performance, security, and cost,
and so are poor fits for integrating multiple APIs.

So, in most cases, we're stuck with good-ole REST, or other forms of JSON-over-HTTP.
Just like any great, durable technology, it has a laundry list of problems,
but its simplicity and ubiquity is an undeniable asset, and not easily improved-upon.

<a id="core-problems"></a>

### Two Core Problems with REST

No matter what you think of REST, there are two fundamental issues that REST,
the other approaches listed above, and HTTP-based integrations generally.

**First: the mechanics of all APIs differ.**

The easiest example is pagination. Is it offset-based, or cursor based?
What are the parameters called? Are pages 0 or 1? What order are results returned in?

Times are another example - is a time an integer in seconds, or milliseconds, or is it an ISO8601 string,
with or without a timezone?

This doesn't begin to scratch the surface of the micro-differences between API schemas.
Every time you integrate an API, you have to learn the choices of the API designers.

**Second: networks are slow and unreliable.**

We know network calls fail, so we build in things like automatic retry.
We know API calls will be slow, so we decouple them from our code via dependency injection.
We know API providers will be down, so we architect our code to be resilient against outages.

These are all absolutely necessary for a good API integration,
but it's also a high cost. On top of that, the first core problem of differing designs
spoils any chance to handle these network issues in a unified cross-API fashion.

**We're stuck.**

So we're in a situation where the status quo is sort-of-okay;
certainly not ideal, but also not bad enough that we're all going to adopt
some new standard and break from decades of progress.

What if we told you that the solution to all of these problems
is actually older than HTTP, just as widely available, and in many circles,
even more loved?

<a id="api2sql"></a>

### The New Paradigm: API2SQL

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

You can [secure your data with your RDBMS's permissions](/docs/securing/),
rather than handing out your API keys to every service that needs to know
anything about the data you store in APIs.
Plus, your API data is now available to even more 3rd parties,
like analytics dashboard tools that can connect to an SQL database.

This is what we call "API2SQL", and in years of using the approach,
we have found it superior to using REST and its alternatives
for API integration in every way.
In fact, we continue to find new uses and benefits
as we roll this new paradigm out on a wider basis.

<a id="blockers"></a>

### Why Aren't we Using API2SQL?

Well, there are a couple of reasons.

First, API providers absolutely *must* offer REST or something else over HTTP.
So anything beyond that is extra work,
and for most teams building an API product, we don't know that offering
customers their data via SQL is a wise investment, since it's a pretty complex implementation.

*I'll note here that, if you are building an API product and want to offer API2SQL,
this is a use case we support. Please reach out to <a href="mailto:hello@webhookdb.com">hello@webhookdb.com</a>.*

Second, REST is still pretty good.
As an analogy: lots of software is still written in C,
even though superior alternatives are available for most use cases.
I suspect we'll be seeing lots of API calls over HTTP for a long time.
But API2SQL offers compelling benefits impossible using HTTP,
the same way using something like Rust offers a set of benefits that are impossible with C.
For this reason, I believe we will see increased API2SQL adoption over time.

<a id="how-it-works"></a>

### How API2SQL works

It's "simple," for a definition of "simple" that involves endless complex details:

- Use a combination of webhooks, period polling, backfilling,
  and other mechanisms to get data from APIs.
- Jam that data into database tables. Normalize and index intelligently.
  Update rows carefully. Augment data that's missing from the API.
- Connect to those tables from your applications, analytics systems,
  and other parts of your business (such as no/low-code apps and automation).

There are many topics to touch on in the future,
including how this pattern scales (really well!),
versioning issues (fewer than REST and GraphQL!),
and data consistency (solved!). But the core of it is really just
getting API data into a database as fast as possible,
and giving your applications a connection string.

Doing this for one API is not a huge undertaking,
if it's just for your organization's use, and the API is well-designed.
But the devil is in the details - what seems simple at first turns into
a massive undertaking. We have been developing WebhookDB in earnest since 2020,
it is the fourth iteration of a system we've built for other companies and clients,
and we're still learning now things.

<a id="today-and-tomorrow"></a>

### API2SQL today (and tomorrow)

To get started with API2SQL today, you can try [WebhookDB](/get-started).
As far as I know, it is the only service today offering this API2SQL innovation.
You can use it as a hosted service, or you can self-host it and run the entire thing yourself
(see our [Guide to Self Hosting](/docs/self-hosting) for more details).
This allows you to get going quickly,
while still knowing you won't run into any performance or data governance issues later.

So yes, we're selling something, but we expect there to be other options, too,
whether home-grown, open-source, or from other companies.
We're here to support this work, and keep the conversation going.
