# frozen_string_literal: true

require "amigo/deprecated_jobs"

Amigo::DeprecatedJobs.install(
  Webhookdb,
  # Put jobs here to die. If you just remove a job in Sidekiq, it may be queued up
  # (like if it's scheduled or retrying),
  # and will fail if the class does not exist.
  #
  # So, make the class exist, but noop so it won't be scheduled and won't be retried.
  # Then it can be deleted later.
  "Jobs::Test::DeprecatedJob",
  "Jobs::ConvertKitBroadcastBackfill",
  "Jobs::ConvertKitSubscriberBackfill",
  "Jobs::ConvertKitTagBackfill",
  "Jobs::RssBackfillPoller",
  "Jobs::TwilioScheduledBackfill",
)
