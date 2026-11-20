# frozen_string_literal: true

module Amigo
end

module Amigo::JobInContext
  class ServerMiddleware
    def call(worker, job, queue, &)
      Sidekiq::Context.with(worker:, queue:, job_hash: job, &)
    end
  end
end
