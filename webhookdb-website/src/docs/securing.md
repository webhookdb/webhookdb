---
title: Securing Your Database
path: /docs/securing
order: 65
---

One of the amazing features of [API2SQL](/docs/api2sql/)
is that you don't need to learn anything new about securing access to your data.

If you are using the hosted version of WebhookDB,
when you create a service integration,
you will get a read-only database URL you can use to access
the replicated data for your organization.

The ability to provision additional and scoped read-only connections
is on our roadmap. Please email <a href="mailto:hello@webhookdb.com">hello@webhookdb.com</a>
if this is something you need.

<a id="self-hosted"></a>

## [Self-Hosted](#self-hosted)

There are two types of database servers you need to worry about when self-hosting.

First is the WebhookDB application database server.
Treat this as a normal application database (try to limit public access, etc.).

The second are the database servers that WebhookDB replicates data to.
Note that this can be the same database server as used by the application.
These servers are usually publicly exposed, but you can also put them into a private network
and proxy requests yourself through your own authentication layer.

Because you run this server yourself, you can administer it in the usual way.
You can create users/roles scoped to just the tables you need.
There are many resources about creating and scoping roles you can refer to.

For example, let's say we have an organization with a single integration:

```arff
$ webhookdb db connection
postgres://aro5a7bca56dae1e774ac:a5a901a18fd3aa56b3a@db.mycompany.com:5432/adb5a7c1e8b
$ webhookdb integrations list
id                   name             table
svi_0d675ecfeb3fb9ed stripe-charges   stripe_charges_v1_d50b
svi_c1lih496odohq4af stripe-customers stripe_customers_v1_fa4d
```

Let's say you want a service to be able to access Stripe Charges,
but not Customers.

Log in as an admin of the `db.mycompany.com` database server,
and run the following:

```sql
CREATE ROLE chargeuser PASSWORD 'abc123' NOSUPERUSER NOCREATEDB NOCREATEROLE NOINHERIT LOGIN;
REVOKE ALL ON SCHEMA public FROM chargeuser;
REVOKE ALL ON ALL TABLES IN SCHEMA public FROM chargeuser;
GRANT CONNECT ON DATABASE adb5a7c1e8b TO chargeuser;
GRANT USAGE ON SCHEMA public TO chargeuser;
GRANT SELECT ON stripe_charges_v1_d50b TO chargeuser;
```

Then you can log in with the new user and confirm you have limited access:

```arff
$ psql postgres://chargeuser:abc123@db.mycompany.com:5432/adb5a7c1e8b

adb5a7c1e8b> select count(1) from stripe_charges_v1_d50b;
0

adb5a7c1e8b> select count(1) from stripe_customers_v1_fa4d;
permission denied for table stripe_customers_v1_fa4d
```

Note that this level of control is impossible to achieve in most APIs,
but you get it "for free" with WebhookDB and SQL.
