# frozen_string_literal: true

require "webhookdb/async/job"

# Put jobs here to die. If you just remove a job in Sidekiq, it may be queued up
# (like if it's scheduled or retrying),
# and will fail if the class does not exist.
#
# So, make the class exist, but noop so it won't be scheduled and won't be retried.
# Then it can be deleted later.
#
module Webhookdb::Jobs::DeprecatedJobs
  NAMES = [
    "Jobs::Test::DeprecatedJob",
    "Jobs::ConvertKitBroadcastBackfill",
    "Jobs::ConvertKitSubscriberBackfill",
    "Jobs::ConvertKitTagBackfill",
  ].freeze

  def self.install
    cls = self.noop_class
    NAMES.each { |n| self.install_one(n, cls) }
  end

  def self.install_one(cls_name, cls)
    name_parts = cls_name.split("::").map(&:to_sym)
    const_base = Webhookdb
    name_parts[0..-2].each do |part|
      const_base = if const_base.const_defined?(part)
                     const_base.const_get(part)
      else
        const_base.const_set(part, Module.new)
      end
    end
    const_base.const_set(name_parts.last, cls)
  end

  def self.noop_class
    cls = Class.new do
      def _perform(*)
        self.logger.warn "deprecated job, remove in the future"
      end
    end
    cls.extend(Webhookdb::Async::Job)
    return cls
  end
end

Webhookdb::Jobs::DeprecatedJobs.install
