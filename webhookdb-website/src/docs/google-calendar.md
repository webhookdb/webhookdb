---
title: Google Calendar
path: /docs/google-calendar
order: 52
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
- POST to WebhookDB when you refresh credentials
- (Optional) POST to WebhookDB when a user revokes access/unlinks their Google account
  (WebhookDB deletes all rows for the user)

**NOTE: WebhookDB does *not* require your application's client ID and secret.**

We'll go over all the steps for integrating Google Calendar.

<a id="create-integrations"></a>

## [Create Integrations](#create-integrations)

This should be simple, since the integrations do not require any additional setup
(you can accept the defaults for the Calendar and Event prompts):

```
webhookdb integrations create google_calendar_list_v1
webhookdb integrations create google_calendar_v1
webhookdb integrations create google_calendar_event_v1
```

We need to get the Calendar List endpoint (this is also printed out during `create`):

    webhookdb integrations info --field=url google_calendar_list_v1

This prints out a URL like `https://api.webhookdb.com/v1/service_integrations/svi_abc123`.
Record it somewhere (like a `.env` file) so it can be read by your application.

Likewise, we need to get the header used to secure the integration
(again, this is also printed out during `create`):

    webhookdb integrations info --field=webhook_secret google_calendar_list_v1

Record this so it can be read by your application too.

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
    "oauth_token": credentials.token,
  }
)
```

<a id="on-refresh"></a>

### [On Refresh](#on-refresh)

At times, you will need to refresh the auth token
(here is the relevant documentation). You must update WebhookDB with the new Access Code:

```python
credentials = Credentials.from_authorized_user_info(
    info={
        "token": user.google_access_token,
        "refresh_token": user.google_refresh_token,
        "client_id": GOOGLE_CLIENT_ID,
        "client_secret": GOOGLE_CLIENT_SECRET,
    },
    scopes=GOOGLE_OAUTH2_SCOPES,
)
if credentials.expired:
    credentials.refresh(Request())
    # Can also be done asynchronously.
    requests.post(
      os.getenv("WEBHOOKDB_GOOGLE_CALENDAR_ENDPOINT"),
      headers={"Whdb-Webhook-Secret": os.getenv("WEBHOOKDB_GOOGLE_CALENDAR_SECRET")},
      json={
        "type": "REFRESHED",
        "oauth_token": credentials.token,
      }
    )
```

<a id="on-unlink"></a>

### [On Unlink](#on-unlink)

If your user unlinks their calendar, you should tell WebhookDB so it can delete all the data for that user.
If for some reason you don't want to delete the data, you don't need to make this request;
WebhookDB will automatically stop trying to sync once the access token is revoked or expires.

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
