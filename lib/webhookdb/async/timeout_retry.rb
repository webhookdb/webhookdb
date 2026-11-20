# frozen_string_literal: true

# Retry synchronously when connecting to the database times out.
# This is unfortunately common in heavy-load scenarios.
# Rather than see it in Sentry, hopefully we can just retry.
module Webhookdb::Async::TimeoutRetry
  MAX_ATTEMPTS = 3

  class ServerMiddleware
    def call(worker, job, queue, &)
      _call_with_retry(worker, job, queue, 1, &)
    end

    def _call_with_retry(_worker, _job, _queue, attempt, &)
      yield
    rescue Sequel::DatabaseConnectionError => e
      raise e unless /connection to server at .* failed: timeout expired/.match?(e.to_s)
      raise e if attempt >= MAX_ATTEMPTS
      attempt += 1
      retry
    end
  end
end
