# frozen_string_literal: true

require "appydays/configurable"
require "webhookdb/slack"

# Decouples the need to alert from the way we want to handle alerts.
# This is for something in between purely technical alerts (error handling in Sentry)
# and ops/marketing alerts (which may post to Slack or whatever).
# Instead of having to rewrite many async jobs to not use Slack,
# we can just modiy the one job that handles developer alerts.
class Webhookdb::DeveloperAlert
  include Appydays::Configurable

  attr_accessor :subsystem, :emoji, :fallback, :fields

  def initialize(subsystem:, emoji:, fallback:, fields:)
    @subsystem = subsystem
    @emoji = emoji
    @fallback = fallback
    @fields = fields
  end

  def as_json
    return {
      subsystem:,
      emoji:,
      fallback:,
      fields:,
    }
  end

  def emit
    Amigo.publish("webhookdb.developeralert.emitted", self.as_json)
  end

  def handle
    notifier = Webhookdb::Slack.new_notifier(
      channel: "#webhookdb-notifications",
      username: @subsystem,
      icon_emoji: @emoji,
    )
    notifier.post(
      attachments: [
        {
          fallback: @fallback,
          fields: @fields,
        },
      ],
    )
  end
end
