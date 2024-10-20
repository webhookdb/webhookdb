# frozen_string_literal: true

require "webhookdb/async/job"

class Webhookdb::Jobs::IncreaseEventHandler
  extend Webhookdb::Async::Job

  on "increase.*"

  def _perform(event)
    self.set_job_tags(increase_event_name: event.name)
    case event.name
      when "increase.oauth_connection.deactivated"
        conn_id = event.payload[0].fetch("associated_object_id")
        self.set_job_tags(result: "increase_oauth_disconnected", oauth_connection_id: conn_id)
        Webhookdb::Oauth::IncreaseProvider.disconnect_oauth(conn_id)
      else
        self.set_job_tags(result: "increase_event_noop")
    end
  end
end
