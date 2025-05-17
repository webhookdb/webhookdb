# frozen_string_literal: true

require "webhookdb/email_octopus"
require "webhookdb/github"
require "webhookdb/sponsy"
require "webhookdb/transistor"

module Webhookdb::Jobs
  # Create a single way to do the common task of automatic scheduled backfills.
  # Each integration that needs automated backfills can add a specification here.
  module ScheduledBackfills
    Spec = Struct.new(:klass, :service_name, :cron_expr, :splay, :incremental, :recursive)

    # @param spec [Spec]
    def self.install(spec)
      cls = Class.new do
        extend Webhookdb::Async::ScheduledJob

        cron spec.cron_expr
        splay spec.splay

        define_method(:_perform) do
          Webhookdb::ServiceIntegration.dataset.where_each(service_name: spec.service_name) do |sint|
            m = spec.recursive ? :create_recursive : :create
            Webhookdb::BackfillJob.send(m, service_integration: sint, incremental: spec.incremental).enqueue
          end
        end
      end
      Webhookdb::Jobs.const_set(spec.klass, cls)
    end

    [
      Spec.new(
        "ConvertkitBroadcastBackfill", "convertkit_broadcast_v1",
        "10 * * * *", 2.minutes, false, false,
      ),
      Spec.new(
        "ConvertkitSubscriberBackfill", "convertkit_subscriber_v1",
        "20 * * * *", 2.minutes, true, false,
      ),
      Spec.new(
        "ConvertkitTagBackfill", "convertkit_tag_v1",
        "30 * * * *", 2.minutes, false, false,
      ),
      Spec.new(
        "EmailOctopusScheduledBackfill", "email_octopus_list_v1",
        Webhookdb::EmailOctopus.cron_expression, 2.minutes, false, true,
      ),
      Spec.new(
        "GithubRepoActivityScheduledBackfill", "github_repository_event_v1",
        Webhookdb::Github.activity_cron_expression, 30.seconds, false,
      ),
      Spec.new(
        # This incremental sync is a backstop for any missed webhooks.
        "IntercomScheduledBackfill", "intercom_marketplace_root_v1",
        "46 4 * * *", 0, true, true,
      ),
      Spec.new(
        "AtomSingleFeedPoller", "atom_single_feed_v1",
        "11 * * * *", 10.seconds, true, false,
      ),
      Spec.new(
        "SponsyScheduledBackfill", "sponsy_publication_v1",
        Webhookdb::Sponsy.cron_expression, 30.seconds, true, true,
      ),
      Spec.new(
        "TransistorEpisodeBackfill", "transistor_episode_v1",
        Webhookdb::Transistor.episode_cron_expression, 2.minutes, true, true,
      ),
      Spec.new(
        "TransistorShowBackfill", "transistor_show_v1",
        Webhookdb::Transistor.show_cron_expression, 2.minutes, true, false,
      ),
      Spec.new(
        "TwilioSmsBackfill", "twilio_sms_v1",
        "*/1 * * * *", 0, true, true,
      ),
      Spec.new(
        "SignalwireMessageBackfill", "signalwire_message_v1",
        "*/1 * * * *", 0, true, true,
      ),
    ].each { |sp| self.install(sp) }
  end
end
