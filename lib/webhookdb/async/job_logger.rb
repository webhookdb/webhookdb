# frozen_string_literal: true

require "appydays/loggable/sidekiq_job_logger"

class Webhookdb::Async::JobLogger < Appydays::Loggable::SidekiqJobLogger
  protected def slow_job_seconds
    return Webhookdb::Async.slow_job_seconds
  end

  def self.durable_job_failure_notifier(job)
    jcls = job["class"]
    jargs = job["args"]
    jid = job["jid"]
    err = [job["error_class"], job["error_message"]].compact.join(": ")
    Webhookdb::DeveloperAlert.new(
      subsystem: "Job Died",
      emoji: ":zombie: ",
      fallback: "Job #{jcls}[#{jid}][#{jargs}] moved to DeadSet: #{err}",
      fields: [
        {title: "Job ID", value: jid, short: true},
        {title: "Job Class", value: jcls, short: true},
        {title: "Args", value: jargs.to_json},
        {title: "Retry", value: job["retry"], short: true},
        {title: "Queue", value: job["queue"], short: true},
        {title: "Dead", value: job["dead"], short: true},
        {title: "Created", value: job["created_at"], short: true},
        {title: "Enqueued", value: job["enqueued_at"], short: true},
        {title: "Error", value: err, short: true},
        {title: "Failed", value: job["failed_at"], short: true},
        {title: "retries", value: job["retry_count"], short: true},
      ],
    ).emit
  end
end
