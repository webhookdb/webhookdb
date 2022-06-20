---
title: Guide
path: /docs/cli
order: 20
---

The WebhookDB api is a developer tool designed to help you interface with your WebhookDB databases. Follow the steps below to initiate and test your first integration. 

<a id="install-the-webhookdb-cli"></a>

## [Install the WebhookDB CLI.](#install-the-webhookdb-cli)

WebhookDB is a single binary (written in Go) that should work on pretty much any OS.

Follow the instructions on our [Download](/download/) page.

You can also try the CLI out using our [terminal in your browser](/terminal/)

You can find the source [on GitHub](https://github.com/lithictech/webhookdb-cli).

<a id="create-or-login-to-your-webhookdb-account"></a>

## [Create or login to your WebhookDB account.](#create-or-login-to-your-webhookdb-account)

WebhookDB uses one-time passwords for authentication. Every time you log in, you'll be asked 
to provide an email. WebhookDB will then send a one-time password to 
that email. To use the OTP, simply enter it in the terminal when prompted. You can also include it with the `token` flag and  
the `username` flag in a separate `auth login` command.

```arff
$ Welcome to WebhookDB!
Please enter your email:

joe@lithic.tech

Welcome back!

To finish logging in, please look for an email we just sent to natalie@lithic.tech.
It contains a One Time Password used to log in.
You can enter it here, or if you want to finish up from a new prompt, use:

  webhookdb auth login --username=joe@lithic.tech --token=<6 digit token>

Enter the token from your email:

***

Welcome! For help getting started, please check out
our docs at https://webhookdb.com/docs/cli.
```

You can also log out:

```arff
$ webhookdb auth logout
You have logged out. 
```
    
<a id="create-or-join-an-organization"></a>

## [Create or join an Organization](#create-or-join-an-organization)

To set up integrations, you need to be part of an Organization.

**NOTE: You get a default organization when you sign up or have been invited to ,
so you can skip this part if you are just taking things for a spin.**

You can create a new organization:

```arff
$ webhookdb org create "Acme Corp"
Your organization identifier is: acme_corp
It is now active.
Use `webhookdb org invite` to invite members to Acme Corp.
```

You can invite others to your organization by using the `username` flag to provide their email address:

```arff
$ webhookdb org invite --username=ashley@webhookdb.com
An invitation has been sent to ashley@webhookdb.com. 
Their invite code is:
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
$ webhookdb integrations list --org=acmecorp
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
convertkit_broadcast_v1
convertkit_subscriber_v1
convertkit_tag_v1
increase_ach_transfer_v1
increase_transaction_v1
shopify_customer_v1
shopify_order_v1
stripe_charge_v1
stripe_customer_v1
transistor_episode_v1
transistor_show_v1
twilio_sms_v1
```

We can then use a service name to create an integration:

```arff
$ webhookdb integrations create stripe_charge_v1
You are about to start reflecting Stripe Charge info into webhookdb.
We've made an endpoint available for Stripe Charge webhooks:

https://api.webhookdb.com/v1/service_integrations/svi_dd4qg2ax629ab022x0pq2fiiq

From your Stripe Dashboard, go to Developers -> Webhooks -> Add Endpoint.
Use the URL above, and choose all of the Charge events.
Then click Add Endpoint.

The page for the webhook will have a 'Signing Secret' section.
Reveal it, then copy the secret (it will start with `whsec_`).
      
Paste or type your secret here: ***

Great! WebhookDB is now listening for Stripe Charges webhooks.
You can query the database through your organization's Postgres connection string:

postgres://d6ab999a:d652560e@bd421d8d.db.webhookdb.com:5432/673a2eaf

You can also run a query through the CLI:

webhookdb db sql "SELECT * FROM stripe_charges_v1_d50b"

If you want to backfill existing Stripe Charges, we'll need your API key.
Run `webhookdb backfill stripe-charges` to get started.
```

<a id="test-your-integration-and-query-your-data"></a>

## [Test your integration and query your data](#test-your-integration-and-query-your-data) 

To check that your integration is working correctly, make a test SQL request. 

```arff
$ webhookdb db sql "SELECT * from stripe_charges_v1_d50b"
```

To see all of the available tables, you can run `\d+` from `psql`,
or from the CLI:

```arff
$ webhookdb db tables
stripe_charges_v1_d50b
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
svi_0d675ecfeb3fb9ed stripe-charges stripe_charges_v1_d50b
```

Then we can kick off a backfill. It will ask for API keys if you have not already added them:

```arff
$ webhookdb backfill svi_0d675ecfeb3fb9ed
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

webhookdb db sql "SELECT * FROM stripe_charges_v1_d50b"
```

Note that for some integrations, WebhookDB is limited in what it can backfill,
such as the last 90 days of Shopify Orders, for example.
The CLI will let you know when we cannot backfill a full history.

<a id="proxy-webhooks"></a>

## [Proxy webhooks](#proxy-webhooks)

If you also need to subscribe to changes in a 3rd party service,
you can subscribe to receive changes from WebhookDB,
rather than having to set up webhooks in each API you use.
This allows you to have a consistent way to configure and verify webhooks.

You can create a webhook subscription either for a single integration or for an 
entire organization: 

```arff
$ webhookdb webhook create --integration=svi_abcdefqwerty
Enter a random secret used to sign and verify webhooks to the given url: webhook_secret123
Enter the URL that WebhookDB should POST webhooks to: https://example.com
All webhooks for this stripe_charge_v1 integration will be sent to https://example.com/
```

```arff
$ webhookdb webhook create --org=acme_corp
Enter a random secret used to sign and verify webhooks to the given url: webhook_secret123
Enter the URL that WebhookDB should POST webhooks to: https://example.com
All webhooks for all integrations belonging to organization Acme Corp will be sent to https://example.com.
```

Once you have created one or more webhooks, you can use the `webhook list` command to view information about them:

```arff
$ webhookdb webhook list                     
       ID               URL            ASSOCIATED TYPE              ASSOCIATED ID          
  54ca14e3c55e  https://example.com   service_integration   svi_c1lih496odohq4aftvzii6l4a  
  27a6a8921777  https://example.com   organization          acme_corp           
```

From there, you can test any webhook by using the opaque id that appears in the list:

```arff
$ webhookdb webhook test 54ca14e3c55e
A test event has been sent to https://example.com.
```

You can also delete webhooks that are no longer needed: 

```arff
$ webhookdb webhook delete 54ca14e3c55e
Events will no longer be sent to https://example.com.
```

<a id="monitor"></a>

## [Monitor your deliveries](#monitor)

You can monitor whether your integration's endpoint is successfully receiving webhooks.
For example, maybe the webhook secret used to sign payloads was changed,
and deliveries are now failing.

You can view the recent delivery history:

```arff
webhookdb integrations stats svi_n5ix69j1on4g4y32z7vlfq1n

           NAME               VALUE   
Count Last 7 Days                  458
Successful Last 7 Days             458
Successful Last 7 Days (Percent) 100.0%
Rejected Last 7 Days                  0
Rejected Last 7 Days (Percent)      0.0%
Successful Of Last 10 Webhooks       10
Rejected Of Last 10 Webhooks          0
```

In the future, you will be able to automatically monitor and alert on failed webhooks.
For now, the WebhookDB team will reach out when we notice
endpoints become undeliverable.

Note that rejected webhooks are preserved and retried for some time,
so can be retried once the secrets are updated.

<a id="unit-testing"></a>

## [Unit Testing with WebhookDB](#unit-testing)

WebhookDB is designed to fit into a unit testing workflow.
There are two parts to integrating it: schema, and data.

To get the schema of a WebhookDB table, you can run:

```arff
webhookdb fixtures stripe_charge_v1
```

This will return the SQL query you can use to build this table:

```sql
CREATE TABLE stripe_charge_v1_fixture (
  pk bigserial PRIMARY KEY,
  "stripe_id" text UNIQUE NOT NULL,
  "amount" numeric ,
  "balance_transaction" text ,
  "billing_email" text ,
  "created" integer ,
  "customer_id" text ,
  "invoice_id" text ,
  "payment_type" text ,
  "receipt_email" text ,
  "status" text ,
  "updated" integer ,
  data jsonb NOT NULL
);
CREATE INDEX IF NOT EXISTS amount_idx ON stripe_charge_v1_fixture ("amount");
CREATE INDEX IF NOT EXISTS balance_transaction_idx ON stripe_charge_v1_fixture ("balance_transaction");
CREATE INDEX IF NOT EXISTS billing_email_idx ON stripe_charge_v1_fixture ("billing_email");
CREATE INDEX IF NOT EXISTS created_idx ON stripe_charge_v1_fixture ("created");
CREATE INDEX IF NOT EXISTS customer_id_idx ON stripe_charge_v1_fixture ("customer_id");
CREATE INDEX IF NOT EXISTS invoice_id_idx ON stripe_charge_v1_fixture ("invoice_id");
CREATE INDEX IF NOT EXISTS payment_type_idx ON stripe_charge_v1_fixture ("payment_type");
CREATE INDEX IF NOT EXISTS receipt_email_idx ON stripe_charge_v1_fixture ("receipt_email");
CREATE INDEX IF NOT EXISTS status_idx ON stripe_charge_v1_fixture ("status");
CREATE INDEX IF NOT EXISTS updated_idx ON stripe_charge_v1_fixture ("updated");
```

Take this SQL, and run it against your test database to generate WebhookDB table facsimiles.
Outside of tests, you will use the real WebhookDB connection string;
but in tests, the connection string will be the same as your (test) application database.

Then, in your unit tests, you can insert data into this database.

For example, let's say that you have an object in your database representing an Invoice to a customer.
You are using Stripe to charge customer bank accounts.
Once the customer submits a payment, you create a Charge in Stripe.
Once the charge settles, you want to update your Invoice.

Your code could look something like this:

```ruby
module Webhookdb
  DATABASE_URL = ENV['WHDB_DATABASE_URL']
  STRIPE_CHARGES_TABLE = ENV['WHDB_STRIPE_CHARGES_TABLE']
  CONN = Sequel.connect(DATABASE_URL)
  
  def self.stripe_charges
    CONN[STRIPE_CHARGES_TABLE]
  end
end

# And in your job, endpoint, etc:

my_invoice = user.invoices_dataset[invoice_id]
charge = Webhookdb.stripe_charges.where(stripe_id: my_invoice.stripe_id).first
if charge[:status] == 'succeeded'
  # handle charge succeeded
elsif charge[:status] == 'failed'
  # handle charge failed
end

# And in your test

fake_invoice.update(stripe_id: 'ch_abc')
Webhookdb.stripe_charges.insert(stripe_id: 'ch_abc', status: 'succeeded')
# run app code and test
```

Compare how simple this is to testing based on mocking HTTP calls!

Needless to say, the application code is also many times faster than
having to check Stripe via its API.

<a id="and-more"></a>

## [Valid DB Identifiers](#db-identifiers)

We've chosen to limit valid database identifiers in cases where we accept user-supplied names.
Any time you provide a database identifier name, like when renaming a table
or create a sync target, the identiier must conform to these rules:

- Begin with an upper or lowercase ASCII letter (`a-zA-z`).
- Contain only upper or lowercase ASCII letters, numbers, underscores, and spaces (`a-zA-Z0-9_ `).

That it, it must match the regular expression `/^[a-zA-Z][a-zA-Z\d_ ]*$/`.

We understand this may be an issue in some rare cases, such as if WebhookDB needs to integrate
with some existing system. If that's the case,
please email <a href="mailto:webhokdb@lithic.tech">webhookdb@lithic.tech</a>
and let us know.

## [And More!](#and-more)

There are many commands not covered here that are of somewhat less interest.

Check out [The Manual](/docs/manual) to see what's available.