# frozen_string_literal: true

require "webhookdb/async/job"

class Webhookdb::Jobs::DeveloperAlertHandle
  extend Webhookdb::Async::Job

  on "webhookdb.developeralert.emitted"

  def _perform(event)
    alert = Webhookdb::DeveloperAlert.new(**event.payload.first.symbolize_keys)
    alert.handle
  end
end
