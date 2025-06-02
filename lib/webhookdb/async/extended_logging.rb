# frozen_string_literal: true

# Middleware to add additional fields to Sentry's :sidekiq context,
# and the structured Amigo job logger.
# Note that Sentry's middleware must be set first.
module Webhookdb::Async::ExtendedLogging
  class ServerMiddleware
    def call(_worker, _job, _queue, &)
      tags = {started_at: Time.now.to_f}
      if (scope = Sentry.get_current_scope)
        scope.set_contexts(sidekiq: tags)
      end
      Webhookdb::Async::JobLogger.with_log_tags(tags, &)
    end
  end
end
