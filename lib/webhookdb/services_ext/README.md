# Proprietary (1st Party) Services

If your organization requires proprietary services,
they can be developed in this folder. They will be
automatically loaded by WebhookDB at runtime.

Services must subclass the `Webhookdb::Services::Base` abstract base class
and implement all abstract methods (all methods in `Base` marked `@abstract`).

Services should have at least some minimum unit testing.
There are many shared behaviors in `shared_examples_for_services.rb`.
The most basic shared examples are covered by `it_behaves_like "a service implementation"`.
Other shared examples are available for integrations that support
additional functionality.

You can look at the code in `webhookdb/services` to see examples of existing WebhookDB integrations.
Between those examples, and the documentation in `Webhookdb::Services::Base`
(and types linked to it),
it should be relatively straightforward to develop your own integrations.