# WebhookDB Web App

## Installation

Install the application dependencies by running:

```sh
make install
```

## Development

Start the application in development mode by running:

```sh
make start
```

## Production

Build the application in production mode by running:

```sh
npm run build
```

Or, from the root `webhookdb/Makefile`:

```sh
make web-build
```

## Hosting

For now, the web app is built manually and checked in.
This isn't ideal, but I don't want to deal with the rigamarole of getting the app building
in both the container and Heroku, like we do with Suma (https://github.com/lithictech/suma).

Run `make web-build`, and check in the diffs in `web-build`.
This is served as a SPA using [`rack-spa`](https://github.com/lithictech/rack-spa)
set up in `apps.rb`.
