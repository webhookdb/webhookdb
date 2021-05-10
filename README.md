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
