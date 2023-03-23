---
path: /blog/2023-03-parquet-sync-coming-soon
date: 2023-03-23T12:00:00
summary: Write Parquet files to Amazon S3 as part of your data pipelines.
title: Continuous Parquet Sync to Amazon S3 
image: apache-parquet.jpg
imageAlt: 
author: Rob Galanakis
draft: false
tags: []
---

WebhookDB can currently sync data from its central storage (PostgreSQL or [DynamoDB](/blog/2023-03-dynamodb-coming-soon))
to another Postgres database, SnowflakeDB, or an arbitrary HTTP endpoint.

Today we are opening a waitlist for syncing data to [Apache Parquet](https://parquet.apache.org/) files
stored in Amazon S3, which is probably *the* most common setup for data analytics tooling.

This uses [WebhookDB's Change Data Capture](/blog/2023-03-cdc-everything) concept
and the the [`webhookdb dbsync`](/docs/dbsync) command to automatically write changes
to Parquet files stored in S3.

This setup, especially combined with serverless central storage like Amazon Aurora Serverless or DynamoDB,
creates exceptionally low operational cost and complexity for WebhookDB.

If you're interested in syncing your data to Parquet files in Amazon S3,
please [let us know](#contact) so we can get you on the waitlist.
