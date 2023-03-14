---
title: Google Calendar
path: /docs/google-calendar
order: 110
---

**NOTICE: Our Google Calendar integration is still in beta.
We'd love for you to try it out!
Please email <a href="mailto:hello@webhookdb.com">hello@webhookdb.com</a>
to be added to our Google Calendar beta.**

The [Google Calendar API](https://developers.google.com/calendar/api/guides/overview)
is a feat of engineering but can be pretty difficult to integrate with properly.
It requires the use of multiple types of auth tokens and secrets,
two different pagination tokens, expiring subscriptions, multiple resources, and more.

WebhookDB makes it extremely easy to integrate with Google Calendar,
but there are still a of couple things to do on your side:

- POST to WebhookDB when a user authorizes your app to access calendars (WebhookDB starts syncing)
- (Optional) POST to WebhookDB when a user revokes access/unlinks their Google account
  (WebhookDB deletes all rows for the user)

We'll go over all the steps for integrating Google Calendar.

<a id="create-integrations"></a>

## [Create Integrations](#create-integrations)

First we need to set up the 'parent' integration,
which holds onto your Google Client ID and Client Secret.
It is where you will POST whenever authorizes your application
and you get a Refresh Token.

    webhookdb integrations create google_calendar_list_v1

Follow the prompts. The two pieces of information you'll want to copy down
are the "webhook secret" (like `zd3zate6c5zfs40zyn44gqwm`), which will sign requests from your backend,
and the "webhook endpoint" (like `https://api.webhookdb.com/v1/service_integrations/svi_abc123`)
which is where you will POST.

Then you'll need to add two more integrations:

    webhookdb integrations create google_calendar_v1
    webhookdb integrations create google_calendar_event_v1

Accept the prompt defaults to link them all together.

<a id="testing"></a>

## [Testing your Integration](#testing)

Before we start writing anything in your backend, it's a good idea to make sure everything is set up right.
Let's use cURL to validate everything is working.

First, get an OAuth Refresh Token, either from your database,
or using the [Google OAuth Playground](https://developers.google.com/oauthplayground/).
Make sure you're using the same Client ID and Client Secret as you sent to WebhookDB.

Put that value into an environment variable in your shell called `REFRESH_TOKEN`,
like `export REFRESH_TOKEN=1//123456abcd`.
Then let's try things out:

```bash
export REFRESH_TOKEN=1//123456abcd-123456abcd
# These values are from when you created the google_calendar_list_v1 integration, as above
export WEBHOOKDB_GOOGLE_CALENDAR_ENDPOINT=https://api.webhookdb.com/v1/service_integrations/svi_alaxblg5llvxb2morb9hw4xs2
export WEBHOOKDB_GOOGLE_CALENDAR_SECRET=a3vgdtr0wje0ywjb73ic0ch3n

# Make a request to link the calendar
curl -X POST -d '{"type":"LINKED","external_owner_id":"test-user","refresh_token":"'"${REFRESH_TOKEN}"'"}' -H "Whdb-Webhook-Secret: ${WEBHOOKDB_GOOGLE_CALENDAR_SECRET}" -H "Content-Type: application/json" "${WEBHOOKDB_GOOGLE_CALENDAR_ENDPOINT}"
```

That's it- you will see data flowing into your database almost immediately.
You can connect to your database and query it (connection parameters are printed out
when you set up the integration, or you can use `webhookdb db connection`).

If for some reason you get a new refresh token, you can tell WebhookDB about it
(set the new one to `REFRESH_TOKEN`):

```bash
curl -X POST -d '{"type":"REFRESHED","external_owner_id":"test-user","refresh_token":"'"${REFRESH_TOKEN}"'"}' -H "Whdb-Webhook-Secret: ${WEBHOOKDB_GOOGLE_CALENDAR_SECRET}" -H "Content-Type: application/json" "${WEBHOOKDB_GOOGLE_CALENDAR_ENDPOINT}"
```

After you've checked out your data, you can delete all the data out of WebhookDB
if you want (or you can leave it- it'll keep syncing, and stop syncing once the token expires;
we show how to send new access tokens below).

```bash
curl -X POST -d '{"type":"UNLINK","external_owner_id":"test-user"}' -H "Whdb-Webhook-Secret: ${WEBHOOKDB_GOOGLE_CALENDAR_SECRET}" -H "Content-Type: application/json" "${WEBHOOKDB_GOOGLE_CALENDAR_ENDPOINT}"
```

<a id="google-auth"></a>

## [Integrating with Google Auth](#google-auth)

Now it's time to modify your application so it tells WebhookDB when
your users link and unlink Google, and your application fetches a refresh token.

<a id="on-link"></a>

### [On Link](#on-link)

When your user links their account (here is the relevant documentation),
you use the "OAuth Access Code" to fetch "OAuth Credentials", like:

```python
# Using the Google Python SDK to request credentials
flow = google_auth_oauthlib.flow.Flow.from_client_config(
    client_config={
        "web": {
            "client_id": GOOGLE_CLIENT_ID,
            "client_secret": GOOGLE_CLIENT_SECRET,
            "auth_uri": "https://accounts.google.com/o/oauth2/auth",
            "token_uri": "https://accounts.google.com/o/oauth2/token",
        }
    },
    redirect_uri=redirect_uri,
    scopes=GOOGLE_OAUTH2_SCOPES,
    state=str(user.id),
)
flow.fetch_token(code=code)
credentials = flow.credentials

# Update WebhookDB. Can also be done asynchronously/in a job system.
requests.post(
  os.getenv("WEBHOOKDB_GOOGLE_CALENDAR_ENDPOINT"),
  headers={"Whdb-Webhook-Secret": os.getenv("WEBHOOKDB_GOOGLE_CALENDAR_SECRET")},
  json={
    "type": "LINKED", 
    "external_owner_id": str(user.id),
    "refresh_token": credentials.refresh_token,
  }
)
```

<a id="on-refresh"></a>

### [On Refresh](#on-refresh)

At times, you may get a new refresh token for a user.
It should be rare, since refresh tokens don't expire, but it happens.
You must update WebhookDB with the new Refresh Token:

```python
# Can also be done asynchronously.
requests.post(
  os.getenv("WEBHOOKDB_GOOGLE_CALENDAR_ENDPOINT"),
  headers={"Whdb-Webhook-Secret": os.getenv("WEBHOOKDB_GOOGLE_CALENDAR_SECRET")},
  json={
    "type": "REFRESHED",
    "refresh_token": credentials.refresh_token,
  }
)
```

<a id="on-unlink"></a>

### [On Unlink](#on-unlink)

If your user unlinks their calendar, you should tell WebhookDB so it can delete all the data for that user.
If for some reason you don't want to delete the data, you don't need to make this request;
WebhookDB will automatically stop trying to sync once the refresh token is revoked.

```python
# Clear out the tokens from your database in whatever way is appropriate.
user.update(google_access_token=None, google_refresh_token=None)

requests.post(
  os.getenv("WEBHOOKDB_GOOGLE_CALENDAR_ENDPOINT"),
  headers={"Whdb-Webhook-Secret": os.getenv("WEBHOOKDB_GOOGLE_CALENDAR_SECRET")},
  json={
    "type": "UNLINKED"
  }
)
```

<a id="force-resync"></a>

### [Force Resync](#force-resync)

There could be cases where you want to force a full resync of a user's Google Calendar
(this should not be needed, but you never know).
You can tell WebhookDB to do a full resync:

```python
requests.post(
  os.getenv("WEBHOOKDB_GOOGLE_CALENDAR_ENDPOINT"),
  headers={"Whdb-Webhook-Secret": os.getenv("WEBHOOKDB_GOOGLE_CALENDAR_SECRET")},
  json={
    "type": "RESYNC"
  }
)
```

<a id="next-steps"></a>

## [Next Steps](#next-steps)

Once WebhookDB is syncing, you have two options for getting the data back out:

1. Use SQL to query the database. Run `webhookdb db credentials` to get your SQL connection string
   and query your Google Calendar tables in your attached WebhookDB database.
2. Use Super Webhooks to get notified about updates.
   This is a powerful-but-simple way to update your own database objects
   whenever changes happen in your attached calendars.
   Check out the [docs on Super Webhooks](/docs/webhooks/). 


<a id="getting-help"></a>

## [Getting Help](#getting-help)

We know from experience that using WebhookDB to integrate a robust Google Calendar sync
is a lot simpler  than using the Google Calendar API directly, but it's still not trivial.
Maybe something like 1-2 hours instead of weeks.

If you need any help, we're here to assist. Just email <a href="mailto:hello@webhookdb.com">hello@webhookdb.com</a>
and we'll get back to you right away.
