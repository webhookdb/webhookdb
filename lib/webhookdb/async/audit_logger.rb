# frozen_string_literal: true

require "appydays/loggable"

require "webhookdb/async/job"

class Webhookdb::Async::AuditLogger
  include Appydays::Loggable
  include Sidekiq::Worker

  def perform(event_json)
    self.class.logger.info "async_job_audit",
                           event_id: event_json["id"],
                           event_name: event_json["name"],
                           event_payload: event_json["payload"]
  end
end
