# frozen_string_literal: true

require "webhookdb/async"
require "webhookdb/async/job"
require "webhookdb/async/scheduled_job"

RSpec.describe "Webhookdb::Async", :db, :async do
  describe "publish matcher" do
    it "can matches against emitted events" do
      expect do
        Webhookdb.publish("my-event-5", 123)
      end.to publish("my-event-5").with_payload([123])

      expect do
        Webhookdb.publish("my-event-5", 123)
      end.to_not publish("my-event-6")
    end
  end

  describe "perform_async_job matcher" do
    let(:job) do
      Class.new do
        extend Webhookdb::MethodUtilities
        extend Webhookdb::Async::Job

        singleton_attr_accessor :result

        on "my-event-*"

        def _perform(event)
          self.class.result = event
        end
      end
    end

    it "runs jobs matching a publish event" do
      expect do
        Webhookdb.publish("my-event-5", 123)
      end.to perform_async_job(job)
      expect(job.result).to have_attributes(payload: [123], name: "my-event-5", id: be_a(String))
    end

    it "does not perform work for published events that do not match the pattern" do
      expect do
        Webhookdb.publish("my-event2-5", 123)
      end.to perform_async_job(job)
      expect(job.result).to be_nil
    end
  end

  describe "job including" do
    it "registers the includer as a job" do
      job = Class.new do
        extend Webhookdb::Async::Job
        on "foo"
      end

      expect(Webhookdb::Async.jobs).to include(job)
    end
  end

  describe "event jobs" do
    it "registers the pattern with the on method" do
      job = Class.new do
        extend Webhookdb::Async::Job
        on "foo"
      end

      expect(Webhookdb::Async.event_jobs).to include(job)
      expect(Webhookdb::Async.scheduled_jobs).to_not include(job)
    end
  end

  describe "ScheduledJob" do
    it "register scheduled work with the every method" do
      job = Class.new do
        extend Webhookdb::Async::ScheduledJob
        cron "*/10 * * * *"
        splay 2.seconds
      end

      expect(Webhookdb::Async.event_jobs).to_not include(job)
      expect(Webhookdb::Async.scheduled_jobs).to include(job)
      expect(job.cron_expr).to eq("*/10 * * * *")
      expect(job.splay_duration).to eq(2.seconds)
    end

    it "has a default splay of 30s" do
      job = Class.new do
        extend Webhookdb::Async::ScheduledJob
      end

      expect(job.splay_duration).to eq(30.seconds)
    end

    it "reschedules itself with a random splay when performed with no arguments" do
      job = Class.new do
        extend Webhookdb::Async::ScheduledJob
        cron "* * * * *"
        splay 1.hour
        def _perform
          raise "should not be reached"
        end
      end

      durations = []
      args = []
      expect(job).to receive(:perform_in).exactly(20).times do |duration, arg|
        durations << duration
        args << arg
      end
      Array.new(20) { job.new.perform }
      expect(durations).to have_length(20)
      expect(durations.uniq).to have_length(be > 1)
      expect(durations).to all(be >= 0)
      expect(durations).to all(be <= 1.hour)
      expect(args).to eq([true] * 20)
    end

    it "executes its inner _perform when performed with true" do
      performed = false
      job = Class.new do
        extend Webhookdb::Async::ScheduledJob
        cron "* * * * *"
        splay 1.hour
        define_method :_perform do
          performed = true
        end
      end

      expect(job).to_not receive(:perform_in)
      job.new.perform(true)
      expect(performed).to be_truthy
    end

    it "can calculate the UTC hour for an hour in a particular timezone" do
      Timecop.freeze("2018-12-27 11:29:30 +0000") do
        job = Class.new do
          extend Webhookdb::Async::ScheduledJob
          cron "57 #{utc_hour(6, 'US/Pacific')} * * *"
        end

        expect(job.cron_expr).to eq("57 14 * * *")
      end

      Timecop.freeze("2018-06-27 11:29:30 +0000") do
        job = Class.new do
          extend Webhookdb::Async::ScheduledJob
          cron "57 #{utc_hour(6, 'US/Pacific')} * * *"
        end

        expect(job.cron_expr).to eq("57 13 * * *")
      end
    end
  end

  describe "audit logging" do
    let(:described_class) { Webhookdb::Async::AuditLogger }
    let(:noop_job) do
      Class.new do
        extend Webhookdb::Async::Job
        def _perform(*); end
      end
    end

    it "logs all events once" do
      logs = capture_logs_from(described_class.logger, level: :info, formatter: :json) do
        expect do
          Webhookdb.publish("some.event", 123)
        end.to perform_async_job(noop_job)
      end
      expect(logs).to contain_exactly(
        include_json(
          "level" => "info",
          name: "Webhookdb::Async::AuditLogger",
          message: "async_job_audit",
          context: {
            event_id: be_a(String),
            event_name: "some.event",
            event_payload: [123],
          },
        ),
      )
    end

    it "can eliminate large strings from the payload" do
      stub_const("Webhookdb::Async::AuditLogger::MAX_STR_LEN", 6)
      stub_const("Webhookdb::Async::AuditLogger::STR_PREFIX_LEN", 2)
      shortstr = "abcdef"
      longstr = "abcdefg"
      payload = {x: {y: {longarr: [shortstr, 1, longstr, 2], longhash: longstr, shorthash: shortstr}}}
      logs = capture_logs_from(described_class.logger, level: :info, formatter: :json) do
        expect do
          Webhookdb.publish("some.event", payload)
        end.to perform_async_job(noop_job)
      end
      expect(logs).to contain_exactly(
        include_json(
          "level" => "info",
          name: "Webhookdb::Async::AuditLogger",
          message: "async_job_audit",
          context: {
            event_id: be_a(String),
            event_name: "some.event",
            event_payload: [{x: {y: {longarr: ["abcdef", 1, "abc...", 2], longhash: "abc...", shorthash: "abcdef"}}}],
          },
        ),
      )
    end
  end
end
