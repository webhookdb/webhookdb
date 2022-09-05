# frozen_string_literal: true

require "amigo/audit_logger"
require "appydays/loggable"

class Webhookdb::Async::AuditLogger < Amigo::AuditLogger
  include Appydays::Loggable

  sidekiq_options queue: "critical"

  MAX_STR_LEN = 64
  STR_PREFIX_LEN = 12

  def perform(event_json)
    j2 = event_json.dup
    j2["payload"] = self.trim_long_strings(j2["payload"], max_str_len: MAX_STR_LEN, str_prefix_len: STR_PREFIX_LEN)
    super(j2)
  end

  def trim_long_strings(v, max_str_len:, str_prefix_len:)
    case v
      when Hash
        v.transform_values do |hv|
          self.trim_long_strings(hv, max_str_len:, str_prefix_len:)
        end
      when Array
        v.map { |item| self.trim_long_strings(item, max_str_len:, str_prefix_len:) }
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
