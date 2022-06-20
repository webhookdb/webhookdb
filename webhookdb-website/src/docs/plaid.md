---
title: Plaid
path: /docs/plaid
order: 50
---

**NOTICE: Our Plaid integration is still in Beta.
We'd love for you to try it out!
Please email <a href="mailto:webhokdb@lithic.tech">webhookdb@lithic.tech</a>
to be added to our Plaid beta.**

Some APIs we integrate with are extremely tricky,
and we cannot create as seamless a user experience as we strive for.
[Plaid](https://plaid.com) is one such API.

In order to integrate WebhookDB with Plaid,
you will need to do some work on your backend
in order to tell WebhookDB when new Items/Access Tokens are created.
This is necessary since 1) Plaid does not let us know about Items,
and 2) your backend telling WebhookDB about Access Tokens
is more secure than having to open an endpoint to us.

A corollary of the above is that WebhookDB will need your Plaid account
secret and item access tokens. While we store the access tokens
in an encrypted column so they cannot be read by the DB,
we still recommend you host your own data or run the self-hosted
version of WebhookDB for particularly sensitive
read/write credentials like this.

All that said- full integration with Plaid resources
that allow syncs, backfills, webhooks, and incremental updates
is extremely complex to set up, and can easily take several weeks to do right.
The changes explained in this document should take less
than a day, and will give you a fully-working Plaid sync
with the resources you configure.

<a id="backend-changes"></a>

## [Required Backend Changes](#backend-changes)

There are, broadly, five (small) things that need to be done to integrate WebhookDB with your Plaid data:

- [Add the webhook URL and secret (provided by WebhookDB) into your application's config.](#add-config)
- [Update where you create your Plaid Link tokens to specify the WebhookDB webhook URL.](#update-plaid-link)
- [POST to the WebhookDB webhook URL from your backend when new Plaid Items are created (the public token is exchanged).](#notify-whdb)
- [Update existing "items" in Plaid itself to use the new WebhookDB webhook URL.](#update-plaid-items)
- [POST to the WebhookDB webhook URL from your backend about existing Plaid Items/Tokens in your database.](#backfill-items)
- (Optional) [Backfill Transaction history of already-fetched accounts.](#backfill-history)

We'll walk through each of these steps exactly as we do them for clients.

<a id="add-config"></a>

### [Add the webhook URL and secret into application config](#add-config)

When you run `webhookdb integrations create plaid_item_v1` from the WebhookDB CLI,
it will prompt for a webhook signing secret; after you enter that, the CLI will print a URL.

Copy these values, and put them into configuration
so your app can read them at runtime.

For example:

```shell
$ echo "WHDB_PLAID_WEBHOOK_URL=https://api.webhookdb.com/v1/integrations/svi_abc" >> ".env"
$ echo "WHDB_PLAID_WEBHOOK_SECRET=longstring" >> ".env"
```

In the below examples, we'll assume environment variables named as above;
replace them with however you handle config in your application.

<a id="update-plaid-link"></a>

### [Update where you create your Plaid Link tokens to specify the webhook URL](#update-plaid-link)

When you create the Plaid Link token, you must specify the webhook that Plaid
will use when items get updated.
This will be the value of `WHDB_PLAID_WEBHOOK_URL`.
Here is a cURL for it; this should be done from your backend.

```shell
curl -X POST https://sandbox.plaid.com/link/token/create -H 'Content-Type: application/json' -d '{
  "client_id": "${CLIENT_ID}",
  "secret": "${SECRET}",
  "user": { "client_user_id": "unique-per-user" },
  "client_name": "My App",
  "products": ["auth"],
  "country_codes": ["US"],
  "language": "en",
  "webhook": ${WHDB_PLAID_WEBHOOK_URL}",
  "redirect_uri": "https://domainname.com/oauth-page.html",
  "account_filters": {
      "depository": {
          "account_subtypes": ["checking"]
      }
  }
}'
```

This will ensure WebhookDB finds out about changes to your Plaid items.
Note that you can still [proxy webhooks](https://webhookdb.com/docs/cli#proxy-webhooks)
using WebhookDB, in case you still need webhooks to hit your backend.

<a id="notify-whdb"></a>

### [Notify WebhookDB about new Tokens/Items](#notify-whdb)

After you exchange your Plaid public token for an access token,
Plaid creates the 'Item' representing this link.
You must tell WebhookDB about the new item,
and provide the access token so we can fetch it
(as mentioned, the token is stored encrypted in your organization's WebhookDB database,
only the WebhookDB server can decrypt it).

Here is an example of how you would do this in Ruby:

```ruby
# These are part of application config, as per earlier steps.
whdb_plaid_webhook_url = ENV['WHDB_PLAID_WEBHOOK_URL']
whdb_plaid_webhook_secret = ENV['WHDB_PLAID_WEBHOOK_SECRET']
# Item ID and access token are returned by Plaid's token exchange call.
item_id = 'created-item-id' 
access_token = 'exchanged-access-token'
body = {
  webhook_type: "ITEM",
  webhook_code: "CREATED",
  item_id: item_id,
  access_token: access_token
}
# Notify WebhookDB about the new token.
resp = Net::HTTP.post(
  URI(whdb_plaid_webhook_url),
  body.to_json,
  {'Content-Type' => 'application/json', 'Whdb-Webhook-Secret' => whdb_plaid_webhook_secret}
)
raise "Bad response: #{resp.inspect}" unless resp.code == '200'
```

Note that both Plaid and your backend POST to the same WebhookDB URL. 

<a id="update-plaid-items"></a>

### [Update existing Items in Plaid itself to use the new webhook URL](#update-plaid-items)

Once that change is deployed, and WebhookDB is notified when new Plaid Items are created,
you must update your existing Plaid Items *in Plaid* so that Plaid sends updates
to WebhookDB, rather than whatever was configured previously.

As per the [Plaid docs](https://plaid.com/docs/api/items/#itemwebhookupdate),
you must run something like this for each item
(refer to Plaid docs for how to run this using their SDKs in various languages):

```shell
curl -X POST https://sandbox.plaid.com/item/webhook/update \
  -H 'Content-Type: application/json' \
  -d '{
    "client_id": ${CLIENT_ID},
    "secret": ${SECRET},
    "access_token": "access token for item",
    "webhook": "${WHDB_PLAID_WEBHOOK_URL}"
  }'
```

<a id="backfill-items"></a>

### [Notify WebhookDB about existing Tokens/Items](#backfill-items)

Once you are telling WebhookDB about new Plaid items,
and Plaid is sending all notifications to WebhookDB,
you must let us know about already-created items
(so that we can act on those Plaid webhooks).
Run the same code you have after the token exchange
for each item/access token you have:

```ruby
whdb_plaid_webhook_url = ENV['WHDB_PLAID_WEBHOOK_URL']
whdb_plaid_webhook_secret = ENV['WHDB_PLAID_WEBHOOK_SECRET']
MyApp::PlaidItem.each do |item|
    body = {
      webhook_type: "ITEM",
      webhook_code: "CREATED",
      item_id: item.plaid_item_id,
      access_token: item.plaid_access_token
    }
    resp = Net::HTTP.post(
      URI(whdb_plaid_webhook_url),
      body.to_json,
      {'Content-Type' => 'application/json', 'Whdb-Webhook-Secret' => whdb_plaid_webhook_secret}
    )
    raise "Bad response: #{resp.inspect}" unless resp.code == '200'
end
```

<a id="backfill-history"></a>

### [Backfill transaction history](#backfill-history)

Plaid sends Transaction webhook notifications for various reasons,
as [explained in their docs](https://plaid.com/docs/api/products/transactions/#webhooks).
As soon as WebhookDB sees one of these, we will backfill all the available transactions.
So the history of items you add (and then request the history for) will always be present,
as will the history of items added before your WebhookDB integration,
once we see a webhook.

If, however, you must trigger a backfill of historical data
separately from getting a Plaid webhook, you can fake one of Plaid's webhooks.
It's recommended you use `HISTORICAL_UPDATE` so we fetch all data
(otherwise we only fetch newer transactions).

Here again is some Ruby code:

```ruby
whdb_plaid_webhook_url = ENV['WHDB_PLAID_WEBHOOK_URL']
whdb_plaid_webhook_secret = ENV['WHDB_PLAID_WEBHOOK_SECRET']
item_id = 'plaid-item-id' 
body = {
  webhook_type: "TRANSACTIONS",
  webhook_code: "HISTORICAL_UPDATE",
  item_id: item_id,
}
resp = Net::HTTP.post(
  URI(whdb_plaid_webhook_url),
  body.to_json,
  {'Content-Type' => 'application/json', 'Whdb-Webhook-Secret' => whdb_plaid_webhook_secret}
)
raise "Bad response: #{resp.inspect}" unless resp.code == '200'
```

<a id="getting-help"></a>

## [Getting Help](#getting-help)

We know integrating with Plaid is pretty complex. But, having done the same thing *without*
WebhookDB takes several times longer, in our experience- something like 1 to 2 hours
(including backfilling) compared to days or weeks. In fact, when working with customers
and clients, we have found it rare that someone gets all of the nuances of their Plaid
integration set up correctly, if at all, such as webhooks.

If you need any help, we're here to assist. Just email <a href="mailto:webhokdb@lithic.tech">webhookdb@lithic.tech</a>
and we'll get back to you right away.
