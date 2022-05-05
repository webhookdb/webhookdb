# frozen_string_literal: true

require "appydays/loggable"

require "webhookdb/async/job"

class Webhookdb::Async::AuditLogger
  include Appydays::Loggable
  include Sidekiq::Worker

  sidekiq_options queue: "critical"

  MAX_STR_LEN = 64
  STR_PREFIX_LEN = 12

  def perform(event_json)
    self.trim_large_payload(event_json, max_str_len: MAX_STR_LEN, str_prefix_len: STR_PREFIX_LEN)
    self.class.logger.info "async_job_audit",
                           event_id: event_json["id"],
                           event_name: event_json["name"],
                           event_payload: event_json["payload"]
  end

  def trim_large_payload(ev_json, max_str_len:, str_prefix_len:)
    self._trim_large_payload(ev_json["payload"], max_str_len:, str_prefix_len:)
  end

  def _trim_large_payload(v, max_str_len:, str_prefix_len:)
    case v
      when Hash
        v.transform_values! do |hv|
          self._trim_large_payload(hv, max_str_len:, str_prefix_len:)
        end
      when Array
        v.map { |item| self._trim_large_payload(item, max_str_len:, str_prefix_len:) }
      when String
        if v.size > max_str_len
          v[..str_prefix_len] + "..."
        else
          v
        end
      else
        v
    end
  end
end
