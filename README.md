# Webhookdb-api

The Webhookdb API is a Ruby app using Puma (webserver), Grape (API framework),
Sequel (ORM), and Postgres (RDBMS).  

## Auth

We use a somewhat novel approach to auth to create a smooth CLI flow.

- `webhookdb auth <email>`
- Error if they are logged in
- Creates an unverified `Customer` if there is none with that email
- Dispatches a OTP to the email
- Customer checks their email, finds a numeric code
- Customer enters that code into the CLI prompt
- Customer is authed and verified
- Token (cookie) is stored on their machine

## Response Shapes

We try to avoid as much rendering logic on the client as possible.

In some cases, like for auth or querying the database,
we deal with bespoke endpoint resonse shapes.
They always have a 'message' field,
but how the response is rendered is up to the CLI.

Otherwise, there are just two response forms we care about:

- Collection responses: They always have a `display_headers` key which is an array of
  `[<item key>, <display field name>]` pairs, like `["billing_email", "Billing email"]`.
  The display headers allow custom strings and an explicit order to be used
  when we render responses.
  The collection of items are under the `items` key.
  For example: `{display_headers: [['email', 'Email']], items: [{email: 'a@b.c'}]}`.
- Single responses. Like collection responses, there is a `display_headers`,
  but each key points to a key in the root object.
  They can be rendered as a key-value list, or tabular like a single-item collection.
  For example: `{display_headers: [['email', 'Email']], email: 'a@b.c'}`.

Note most every response has a 'message' at its top level.
Usually this is displayed to the user.

## Custom Schemas

When a customer wants to change the schemas for their tables,
we do the following (see `Organization.migrate_replication_schema`):

- Use the admin connection to create the schema if it doesn't exist.
- Move the tables for all integrations into the new schema.
- Grant SELECT access on the schema to the readonly user.

Note that we do not check if a schema exists on each upsert,
since it's extra work we should not have to redo each upsert
(while we do need to ensure the table exists before we upsert a webhook).
