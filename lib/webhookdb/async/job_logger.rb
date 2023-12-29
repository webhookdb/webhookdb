# frozen_string_literal: true

require "appydays/loggable/sidekiq_job_logger"

class Webhookdb::Async::JobLogger < Appydays::Loggable::SidekiqJobLogger
  protected def slow_job_seconds
    return Webhookdb::Async.slow_job_seconds
  end

  def self.durable_job_failure_notifier(job)
    # See https://github.com/sidekiq/sidekiq/wiki/Job-Format#activejob-middleware-format
    # for job format.
    job = job.dup
    # These fields always exist.
    jargs = job.delete("args")
    jcls = job.delete("class")
    jid = job.delete("jid")
    jq = job.delete("queue")
    jcreated = job.delete("created_at")
    safe_fields = [
      {title: "Job ID", value: jid, short: true},
      {title: "Job Class", value: "`#{jcls}`", short: true},
      {title: "Args", value: "```#{jargs.to_json}```"},
      {title: "Queue", value: jq, short: true},
      {title: "Created At", value: self._ts("created_at", jcreated), short: true},
    ]
    # The remaining fields can be added dynamically.
    other_fields = job.compact.
      map { |k, v| {title: k.humanize, value: self._ts(k, v), short: true} }
    Webhookdb::DeveloperAlert.new(
      subsystem: "Job Died",
      emoji: ":zombie:",
      fallback: "Job #{jcls}[#{jid}][#{jargs}] moved to DeadSet",
      fields: safe_fields + other_fields,
    ).emit
  end

  def self._ts(k, v)
    return nil if v.nil?
    return v unless k.end_with?("_at")
    return Time.at(v) if v.is_a?(Numeric)
    return Time.parse(v) if v.is_a?(String)
    return v
  end
end
