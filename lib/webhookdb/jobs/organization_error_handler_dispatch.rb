# frozen_string_literal: true

require "webhookdb/async/job"

class Webhookdb::Jobs::OrganizationErrorHandlerDispatch
  extend Webhookdb::Async::Job

  sidekiq_options queue: "netout"

  def perform(error_handler_id, payload)
    eh = self.lookup_model(Webhookdb::Organization::ErrorHandler, error_handler_id)
    self.set_job_tags(error_handler_id: eh.id, **eh.organization.log_tags)
    begin
      eh.dispatch(payload)
      self.set_job_tags(result: "success")
    rescue StandardError => e
      # Don't bother logging these errors out
      self.set_job_tags(result: "error")
      self.logger.debug("organization_error_handler_post_error", error: e)
      raise Amigo::Retry::OrDie.new(
        Webhookdb::Organization::Alerting.error_handler_retries,
        Webhookdb::Organization::Alerting.error_handler_retry_interval,
      )
    end
  end
end
