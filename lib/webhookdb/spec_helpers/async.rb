# frozen_string_literal: true

require "sidekiq/testing"

require "webhookdb/async"
require "webhookdb/spec_helpers"

module Webhookdb::SpecHelpers::Async
  def self.included(context)
    Sidekiq::Testing.inline!

    context.before(:each) do |example|
      Webhookdb::Async.synchronous_mode = true if example.metadata[:async]
      Webhookdb::Postgres.do_not_defer_events = true if example.metadata[:do_not_defer_events]
      Webhookdb::Slack.http_client = Webhookdb::Slack::NoOpHttpClient.new if example.metadata[:slack]
    end

    context.after(:each) do |example|
      Webhookdb::Async.synchronous_mode = false if example.metadata[:async]
      Webhookdb::Postgres.do_not_defer_events = false if example.metadata[:do_not_defer_events]
      Webhookdb::Slack.http_client = nil if example.metadata[:slack]
    end

    super
  end

  module_function def snapshot_async_state(opts={})
    old_hooks = Webhookdb.subscribers.to_a
    old_jobs = Webhookdb::Async.jobs.to_a
    old_failure = Webhookdb.on_publish_error

    begin
      Webhookdb.on_publish_error = opts[:on_error] if opts.key?(:on_error)
      Webhookdb.subscribers.replace(opts[:subscribers]) if opts.key?(:subscribers)
      Webhookdb::Async.jobs.replace(opts[:jobs]) if opts.key?(:jobs)
      yield
    ensure
      Webhookdb.on_publish_error = old_failure
      Webhookdb.subscribers.replace(old_hooks)
      Webhookdb::Async.jobs.replace(old_jobs)
    end
  end

  class EventPublishedMatcher
    include Appydays::Loggable

    attr_reader :recorded_events

    def initialize(eventname, expected_payload=[])
      @expected_events = [[eventname, expected_payload]]
      @recorded_events = []
      @missing         = []
      @matched         = []
    end

    def and(another_eventname, *expected_payload)
      @expected_events << [another_eventname, expected_payload]
      return self
    end

    def with_payload(expected_payload)
      raise ArgumentError, "expected payload must be an array or matcher" unless
        expected_payload.is_a?(Array) || expected_payload.respond_to?(:matches?)
      @expected_events.last[1] = expected_payload
      return self
    end

    def record_event(event)
      self.logger.debug "Recording event: %p" % [event]
      @recorded_events << event
    end

    def supports_block_expectations?
      true
    end

    def matches?(given_proc)
      unless given_proc.respond_to?(:call)
        warn "publish matcher used with non-proc object #{given_proc.inspect}"
        return false
      end

      unless Webhookdb::Async.synchronous_mode?
        warn "publish matcher used without synchronous_mode (use :async test metadata)"
        return false
      end

      state = {on_error: self.method(:on_publish_error), subscribers: [self.method(:record_event)]}
      Webhookdb::SpecHelpers::Async.snapshot_async_state(state) do
        given_proc.call
      end

      self.match_expected_events

      return @error.nil? && @missing.empty?
    end

    def on_publish_error(err)
      @error = err
    end

    def match_expected_events
      @expected_events.each do |expected_event, expected_payload|
        match = @recorded_events.find do |recorded|
          recorded.name == expected_event && self.payloads_match?(expected_payload, recorded.payload)
        end

        if match
          Webhookdb.logger.debug "Found a match for {%s:%p}: %p" %
            [expected_event, expected_payload, match]
          self.add_matched(expected_event, expected_payload)
        else
          self.add_missing(expected_event, expected_payload)
        end
      end
    end

    def payloads_match?(expected, recorded)
      return expected.matches?(recorded) if expected.respond_to?(:matches?)
      return expected.nil? || expected.empty? || expected == recorded
    end

    def add_matched(event, payload)
      @matched << [event, payload]
    end

    def add_missing(event, payload)
      @missing << [event, payload]
    end

    def failure_message
      return "Error while publishing: %p" % [@error] if @error

      messages = []

      @missing.each do |event, payload|
        message = "expected a '%s' event to be fired" % [event]
        message << (" with a payload of %p" % [payload]) unless payload.nil?
        message << " but none was."

        messages << message
      end

      if @recorded_events.empty?
        messages << "No events were sent."
      else
        parts = @recorded_events.map(&:inspect)
        messages << ("The following events were recorded: %s" % [parts.join(", ")])
      end

      return messages.join("\n")
    end

    def failure_message_when_negated
      messages = []
      @matched.each do |event, _payload|
        message = "expected a '%s' event not to be fired" % [event]
        message << (" with a payload of %p" % [@expected_payload]) if @expected_payload
        message << " but one was."
        messages << message
      end

      return messages.join("\n")
    end
  end

  ### RSpec matcher -- set up an expectation that an event will be fired
  ### with the specified +eventname+ and optional +expected_payload+.
  ###
  ###    expect {
  ###        Webhookdb::Customer.create( attributes )
  ###    }.to publish( 'webhookdb.customer.create' )
  ###
  ###    expect {
  ###        Webhookdb::Customer.create( attributes )
  ###    }.to publish( 'webhookdb.customer.create', [1] )
  ###
  ###    expect { enter_hatch() }.
  ###        to publish( 'webhookdb.hatch.entered' ).
  ###        with_payload( [4, 8, 15, 16, 23, 42] )
  ###
  ###    expect { cook_potatoes() }.
  ###        to publish( 'webhookdb.potatoes.cook' ).
  ###        with_payload( including( a_hash_containing( taste: 'good' ) ) )
  ###
  def publish(eventname=nil, expected_payload=nil)
    return EventPublishedMatcher.new(eventname, expected_payload)
  end

  class PerformAsyncJobMatcher
    include RSpec::Matchers::Composable
    include Appydays::Loggable

    def initialize(job)
      @job = job
    end

    ### RSpec matcher API -- specify that this matcher supports expect with a block.
    def supports_block_expectations?
      true
    end

    ### Return +true+ if the +given_proc+ is a valid callable.
    def valid_proc?(given_proc)
      return true if given_proc.respond_to?(:call)

      warn "`perform_async_job` was called with non-proc object #{given_proc.inspect}"
      return false
    end

    ### RSpec matcher API -- return +true+ if the specified job ran successfully.
    def matches?(given_proc)
      return false unless self.valid_proc?(given_proc)
      return self.run_isolated_job(given_proc)
    end

    # Run +given_proc+ in a 'clean' async environment, where 'clean' means:
    # - Async jobs are subscribed to events
    # - The only registered job is the matcher's job
    def run_isolated_job(given_proc)
      unless Webhookdb::Async.synchronous_mode?
        warn "publish matcher used without synchronous_mode (use :async test metadata)"
        return false
      end

      state = {on_error: self.method(:on_publish_error), subscribers: [], jobs: [@job]}
      Webhookdb::SpecHelpers::Async.snapshot_async_state(state) do
        Webhookdb::Async.register_subscriber
        given_proc.call
      end

      return @error.nil?
    end

    def on_publish_error(err)
      @error = err
    end

    def failure_message
      return "Job errored: %p" % [@error]
    end
  end

  def perform_async_job(job)
    return PerformAsyncJobMatcher.new(job)
  end
end
