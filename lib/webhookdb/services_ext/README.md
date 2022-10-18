# Proprietary (1st Party) Replicators

If your organization requires proprietary replicators,
they can be developed in this folder. They will be
automatically loaded by WebhookDB at runtime.

Replicators must subclass the `Webhookdb::Replicator::Base` abstract base class
and implement all methods marked `@abstract`.
Many methods are optionally overridden, to control particular behavior.
These methods are marked `@virtual`, and you may want to review them
to better understand the capabilities of replicators. 

Replicators should have at least some minimum unit testing.
There are many shared behaviors in `shared_examples_for_replicators.rb`.
The most basic shared examples are covered by `it_behaves_like "a replicator"`.
Other shared examples are available for replicators that support
additional functionality.

You can look at the code in `webhookdb/replicator` to see examples of existing WebhookDB replicators.
Between those examples, and the documentation in `Webhookdb::Replicator::Base`
(and types linked to it),
it should be relatively straightforward to develop your own integrations.
