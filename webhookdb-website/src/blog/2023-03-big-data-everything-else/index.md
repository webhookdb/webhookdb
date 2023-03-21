---
path: /blog/2023-03-big-data-everything-else
date: 2023-03-23T12:00:00
summary: Big data problems require big data solutions and tradeoffs. But very few problems are big data problems.
title: Don't make big problems out of small data
image: nasa-Q1p7bh3SHj8-unsplash.jpg
imageAlt: earth at night from space station
author: Rob Galanakis
draft: false
tags: []
---

### Ten thousand hundred thousands

There are some types of data sources that lead to extremely large data sets.
100,000 active customers can generate a lot of application metrics and monitoring datapoints, for example.
But most of the data for 100,000 customers (which, let's face it, is more than most companies ever get to)
look more like millions of rows, not billions.

For example, if customers get a monthly invoice,
you are generating 100,000 new chargers per month (congratulations!).
While it would take about 10 months to get to 1 million rows,
it would take **800 years** (ten thousand months) to get to 1 billion rows.

It's very difficult to get from millions to billions.

While there isn't a single definition of 'big data,'
one we use is "requires specialized tools to manage effectively."

While some big data tools are really nice to work with
(looking at you, Snowflake), they're usually expensive, proprietary, and/or hard to run.
On the other hand, commodity data tools, like PostgreSQL,
are ubiquitous and run everywhere. They do have problems at very large sizes
(say, a billion rows), but very few datasets are likely to get to that point.

### Don't make big data problems out of small data problems

Maybe this situation sounds familiar:

- Your application syncs data from APIs like Stripe, and/or queries APIs heavily.
- Your data pipelines also sync data from these APIs to send to S3, SnowflakeDB, or another warehouse.
  They use an off the shelf sync solution, like available in Hevo or Fivetran.
- Your application also has to work with the some uncommon APIs.
- No off-the-shelf sync solution is available for this API, so you have some one-off Lambdas that sync to your warehouse.
- And the complexity goes on and on...

Nearly every organization is in this situation.
It's a collection of individually rational decisions that, in sum, is clumsy, slow, and often painfully expensive.

How do you cut through this Gordian Knot? How can you have a single service that:

- Syncs from any data source (even that weird or brand new SaaS API you use),
- Syncs to any data source, and
- Is easy to monitor and maintain?

Well, the **"one weird trick"** we've learned building all sorts of data pipelines is that
good commodity software can solve a huge variety of problems. It's simpler to operate,
scales better than anything else, and has a *much* lower Total Cost of Ownership
(this is especially true when you factor in serverless databases).

This is what the philosophy of WebhookDB boils down to:
we can use commodity tools and services to solve most problems,
and save customers time and money in the short and long term.

If you're ready to simplify your application and data pipelines, and lower cost and complexity,
[give WebhookDB a try](/docs/guide) or [let us know what you think](#contact).
