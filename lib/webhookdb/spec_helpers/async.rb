# frozen_string_literal: true

require "sidekiq/testing"

require "webhookdb/async"
require "webhookdb/slack"
require "webhookdb/spec_helpers"

module Webhookdb::SpecHelpers::Async
  def self.included(context)
    Sidekiq::Testing.inline!
    Amigo::QueueBackoffJob.reset

    context.before(:each) do |example|
      if (sidekiq_mode = example.metadata[:sidekiq])
        Sidekiq::Testing.send(:"#{sidekiq_mode}!")
      else
        Sidekiq::Testing.inline!
      end
      Webhookdb::Postgres.do_not_defer_events = true if example.metadata[:do_not_defer_events]
      if example.metadata[:slack]
        Webhookdb::Slack.http_client = Webhookdb::Slack::NoOpHttpClient.new
        Webhookdb::Slack.suppress_all = false
      end
    end

    context.after(:each) do |example|
      Webhookdb::Postgres.do_not_defer_events = false if example.metadata[:do_not_defer_events]
      if example.metadata[:slack]
        Webhookdb::Slack.http_client = nil
        Webhookdb::Slack.reset_configuration
      end
      Webhookdb::Sentry.reset_configuration if example.metadata[:sentry]
      Sidekiq::Queues.clear_all if example.metadata[:sidekiq] && Sidekiq::Testing.fake?
    end
    super
  end

  module_function def job_hash(cls, **more)
    params = {"class" => cls.to_s}
    params.merge!(more.stringify_keys)
    return hash_including(params)
  end

  RSpec::Matchers.define(:have_queue) do |passed_name|
    match do |sk|
      raise "Sidekiq::Testing must be in fake mode" unless Sidekiq::Testing.fake?
      raise ArgumentError, "argument must be Sidekiq, got #{sk.inspect}" unless sk == Sidekiq
      @name = passed_name || "default"
      q = Sidekiq::Queues[@name]
      if @size
        break true if @size.zero? && q.empty?
        if q.size != @size
          @_err = "has size #{q.size}, expected #{@size}"
          break false
        end
      end
      if q.empty?
        @_err = "is empty"
        break false
      end
      (@matchers || []).each do |m|
        expect(q).to include(m)
      end
    end

    failure_message do |*|
      msg = "failed to match Sidekiq queue %s:" % @name
      msg += " " + @_err if @_err
      lines = [msg]
      Sidekiq::Queues.jobs_by_queue.each do |n, jobs|
        lines << "  #{n}"
        jobs.each do |j|
          lines << "    #{j}"
        end
      end
      lines.join("\n")
    end

    chain :named do |n|
      @name = n
    end

    chain :including do |*matchers|
      @matchers ||= []
      @matchers.concat(*matchers)
    end

    chain :consisting_of do |*matchers|
      @matchers = matchers
      @size = matchers.size
    end

    chain :of_size do |n|
      @size = n
    end
  end

  RSpec::Matchers.define(:have_empty_queues) do |*|
    match do |sk|
      raise "Sidekiq::Testing must be in fake mode" unless Sidekiq::Testing.fake?
      raise ArgumentError, "argument must be Sidekiq, got #{sk.inspect}" unless sk == Sidekiq
      @nonempty = Sidekiq::Queues.jobs_by_queue.select { |_n, jobs| jobs.size.positive? }
      @nonempty.empty?
    end

    failure_message do |*|
      lines = ["Sidekiq queues have jobs:"]
      Sidekiq::Queues.jobs_by_queue.each do |n, jobs|
        lines << "  #{n}"
        jobs.each do |j|
          lines << "    #{j}"
        end
      end
      lines.join("\n")
    end
  end
end
