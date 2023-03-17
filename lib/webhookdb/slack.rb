# frozen_string_literal: true

require "appydays/configurable"
require "slack-notifier"

require "webhookdb"

class Webhookdb::Slack
  include Appydays::Configurable
  extend Webhookdb::MethodUtilities

  # Set this during testing
  singleton_attr_accessor :http_client
  @http_client = nil

  configurable(:slack) do
    setting :webhook_url, "http://unconfigured-slack-webhook"
    setting :channel_override, nil
    setting :suppress_all, false
  end

  def self.new_notifier(opts={})
    opts[:channel] ||= "#eng-naboo"
    opts[:username] ||= "Unknown"
    opts[:icon_emoji] ||= ":question:"
    opts[:channel] = self.channel_override if self.channel_override
    if (force_chan = opts.delete(:force_channel))
      opts[:channel] = force_chan
    end
    return ::Slack::Notifier.new(self.webhook_url) do
      defaults opts
      if Webhookdb::Slack.suppress_all
        http_client NoOpHttpClient.new
      elsif Webhookdb::Slack.http_client
        http_client Webhookdb::Slack.http_client
      end
    end
  end

  def self.ignore_channel_not_found
    yield()
  rescue ::Slack::Notifier::APIError => e
    return if e.message.include?("channel_not_found")
    return if e.message.include?("channel_is_archived")
    raise e
  end

  def self.post_many(channels, notifier_options: {}, payload: {})
    channels.each do |chan|
      notifier = self.new_notifier(notifier_options.merge(channel: chan))
      self.ignore_channel_not_found do
        notifier.post(payload)
      end
    end
  end

  class NoOpHttpClient
    attr_reader :posts

    def initialize
      @posts = []
    end

    def post(uri, params={})
      self.posts << [uri, params]
    end
  end
end
