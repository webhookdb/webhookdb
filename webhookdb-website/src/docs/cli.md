---
title: Guide
path: /docs/cli
order: 2
---

The WebhookDB api is a developer tool designed to help you interface with your WebhookDB databases. Follow the steps below to initiate and test your first integration. 

<a id="install-the-webhookdb-cli"></a>

## [Install the WebhookDB CLI.](#install-the-webhookdb-cli)

WebhookDB is a single binary (written in Go) that should work on pretty much any OS.

Follow the instructions on our [Download](https://webhookdb.com/download/) page.

You can find the source [on GitHub](https://github.com/lithictech/webhookdb-cli).

<a id="create-or-login-to-your-webhookdb-account"></a>

## [Create or login to your WebhookDB account.](#create-or-login-to-your-webhookdb-account)

WebhookDB uses one-time passwords for authentication. Every time you log in, you'll be asked 
to provide an email with the `username` flag. WebhookDB will then send a one-time password to 
that email: 

```arff
$ webhookdb auth login --username joe@webhookdb.com
Please check your email joe@webhookdb.com for a login code.
```

To use the OTP, include it with the `token` flag to the `auth otp` command: 

```arff
$ webhookdb auth otp --username joe@webhookdb.com --token 123456
You are now logged in as joe@webhookdb.com
```

You can also log out:

```arff
$ webhookdb auth logout
You have logged out. 
```
    
<a id="create-or-join-an-organization"></a>

## [Create or join an Organization](#create-or-join-an-organization)

To set up integrations, you need to be part of an Organization.

You can create a new organization:

```arff
$ webhookdb org create
What is your organization name? Acme Corp
Your organization identifier is: acmecorp
```

You can invite others to your organization:

```arff
$ webhookdb org invite --username=ashley@webhookdb.com
An invitation has been sent to ashley@webhookdb.com. Their invite code is:
join-f26b81a2
```


If you have an invitation code, you can use it to join that organization:

```arff
$ webhookdb org join join-568eb975
Congratulations! You are now a member of Acme Corp.
```

List members of an organization:

```arff
$ webhookdb org members
joe@webhookdb.com (admin)
ashley@webhookdb.com (invited)
```

Remove someone from your organization (invited or an actual member):

```arff
$ webhookdb org remove ashley@webhookdb.com
ashley@webhookdb.com is no longer a part of the Acme Corp organization.
```

If you are a part of multiple organizations, you can choose which is active:

```arff
$ webhookdb org list
acmecorp (active)
justiceleague
$ webhookdb org activate justiceleague
Justice League is now your active organization.
```

You can also override the organization for a specific command:

```arff
$ webhookdb --org=acmecorp integrations list
```

<a id="add-an-integration"></a>

## [Add an integration](#add-an-integration) 

The steps here will depend on which service you want to connect with. Essentially, 
WebhookDB needs auth information in order to access the given API, but where that 
information can be found will vary from service to service. Each service/resource 
will take you through the process of setting up its integration. For this example, 
we will set up an integration with Stripe Charges.

Let's see what services are available:

```arff
$ webhookdb services list
shopify_customer_v1
shopify_order_v1
stripe_charge_v1
stripe_customer_v1
twilio_sms_v1
```

We can then use a service name to create an "integration":

```arff
$ webhookdb integrations create stripe_charge_v1
You are about to start reflecting Stripe Charges into webhookdb.
We've made an endpoint available for Stripe Charges webhooks:

https://api.webhookdb.com/v1/integrations/0d675ecfeb3fb9ed

From your Stripe Dashboard, go to Developers -> Webhooks -> Add Endpoint.
Use the URL above, and choose all of the Charges events.
Then click Add Endpoint.

The page for the webhook will have a 'Signing Secret' section.
Reveal it, then copy the secret (it will start with `whsec_`).

Paste or type your secret here: ***

Great! WebhookDB is now listening for Stripe Charges webhooks.
You can query the database through your organization's Postgres connection string:

postgres://d6ab999a:d652560e@bd421d8d.db.webhookdb.com:5432/673a2eaf

You can also run a query through the CLI:

webhookdb db sql "SELECT * FROM stripe_charges_v1"

If you want to backfill existing Stripe Charges, we'll need your API key.
Run `webhookdb backfill stripe-charges` to get started.
```

<a id="test-your-integration-and-query-your-data"></a>

## [Test your integration and query your data](#test-your-integration-and-query-your-data) 

To check that your integration is working correctly, make a test SQL request. 

```arff
$ webhookdb db sql "SELECT * from stripe_charges_v1"
```

To see all of the available tables, you can run `\d+` from `psql`,
or from the CLI:

```arff
$ webhookdb db tables
stripe_charges_v1
```

<a id="backfill-existing-data"></a>

## [Backfill existing data](#backfill-existing-data)

WebhookDB will add any new and updated resources to your database,
but cannot access historical data without some privileges.
You can run a command to start a backfill of all the resources available to an integration.
First, list the integrations to find the one to backfill:

```arff
$ webhookdb integrations list
id               name           table
0d675ecfeb3fb9ed stripe-charges stripe_charges_v1
```

Then we can kick off a backfill. It will ask for API keys if you have not already added them:

```arff
$ webhookdb backfill 0d675ecfeb3fb9ed
In order to backfill Stripe Charges, we need an API key.
From your Stripe Dashboard, go to Developers -> API Keys -> Restricted Keys -> Create Restricted Key.
Create a key with Read access to Charges.
Submit, then copy the key when Stripe shows it to you:

Paste or type your Restricted Key here: ***

Great! We are going to start backfilling your Stripe Charges.
Stripe allows us to backfill your entire history of charges,
so you're in good shape.

You can query the database through your organization's Postgres connection string:
    
postgres://d6ab999a:d652560e@bd421d8d.db.webhookdb.com:5432/673a2eaf

You can also run a query through the CLI:

webhookdb db sql "SELECT * FROM stripe_charges_v1"
```

Note that for some integrations, WebhookDB is limited in what it can backfill,
such as the last 90 days of Shopify Orders, for example.
The CLI will let you know when we cannot backfill a full history.
