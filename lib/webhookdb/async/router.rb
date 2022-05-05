# frozen_string_literal: true

require "webhookdb/async/job"

class Webhookdb::Async::Router
  include Sidekiq::Worker

  sidekiq_options queue: "critical"

  def perform(event_json)
    event_name = event_json["name"]
    matches = Webhookdb::Async.event_jobs.select { |job| File.fnmatch(job.pattern, event_name, File::FNM_EXTGLOB) }
    matches.each do |job|
      Webhookdb::Async.synchronous_mode? ? job.new.perform(event_json) : job.perform_async(event_json)
    end
  end
end
