# frozen_string_literal: true

require "amigo/durable_job"

RSpec.describe Amigo::DurableJob do
  before(:all) do
    @superuser_url = Webhookdb::Postgres::Model.uri
    @db1_url = change_db(@superuser_url, "/djdb1")
    @db2_url = change_db(@superuser_url, "/djdb2")
    Sequel.connect(@superuser_url) do |db|
      ["djdb1", "djdb2"].each do |name|
        db << "DROP DATABASE IF EXISTS #{name}"
        db << "CREATE DATABASE #{name}"
      end
    end
    @db1 = Sequel.connect(@db1_url)
    @db2 = Sequel.connect(@db2_url)
  end

  def change_db(url, name)
    u = URI(url)
    u.path = name
    return u.to_s
  end

  let(:db1_url) { @db1_url }
  let(:db2_url) { @db2_url }
  let(:db1) { @db1 }
  let(:db2) { @db2 }
  let(:ds1) { @db1[:durable_jobs] }
  let(:ds2) { @db2[:durable_jobs] }

  before(:each) do
    Sidekiq::Testing.fake!
    described_class.reset_configuration
    described_class.server_urls = [db1_url, db2_url]
    described_class.server_env_vars = []
    described_class.run_after_configured_hooks
    described_class.storage_datasets.each(&:delete)
  end

  after(:each) do
    allow(Sidekiq.logger).to receive(:error)
    Sidekiq::Worker.drain_all
  end

  def create_job_class(callback=nil)
    cls = Class.new do
      include Sidekiq::Worker
      include Amigo::DurableJob

      define_method(:perform) do |*args|
        callback && callback[self, args]
      end

      def self.to_s
        return "DurableJob::TestWorker"
      end
    end
    stub_const(cls.to_s, cls)
    cls
  end

  it "creates the durable jobs table in each configured database" do
    expect(@db1).to be_table_exists(:durable_jobs)
    expect(@db2).to be_table_exists(:durable_jobs)
  end

  describe "adding the job" do
    it "pushes into the first database on client_push and all perform_async variants" do
      cls = create_job_class
      j1 = cls.perform_async({x: 1})
      j2 = cls.perform_in(10.minutes, [1, 2, 3])
      j3 = cls.perform_at(5.minutes.from_now)
      expect(ds1.where(job_id: [j1, j2, j3]).all).to contain_exactly(
        include(
          job_id: j1,
          job_item_json: include('"args":[{"x":1}]').and(include('"class":"DurableJob::TestWorker"')),
          locked_by: nil,
          assume_dead_at: match_time(5.minutes.from_now).within(5),
        ),
        include(
          job_id: j2,
          job_item_json: include('"args":[[1,2,3]]'),
          assume_dead_at: match_time(15.minutes.from_now).within(5),
        ),
        include(
          job_id: j3,
          job_item_json: include('"args":[]'),
          assume_dead_at: match_time(10.minutes.from_now).within(5),
        ),
      )
      expect(ds2.where(job_id: [j1, j2, j3]).all).to be_empty
    end

    it "falls back to other databases" do
      expect(Sidekiq.logger).to receive(:warn)
      described_class.storage_databases[0] =
        Sequel.connect("postgres://x:y@localhost:1/nope", test: false, keep_reference: false)
      cls = create_job_class
      j1 = cls.perform_async
      expect(ds1.where(job_id: [j1]).all).to be_empty
      expect(ds2.where(job_id: [j1]).all).to contain_exactly(
        include(job_item_json: include('"args":[]'), job_id: j1),
      )
    end

    it "logs errors if no database is available" do
      expect(Sidekiq.logger).to receive(:error)
      described_class.storage_databases.clear
      cls = create_job_class
      cls.perform_async
    end

    it "not suspectible to a Redis/Postgres race with Redis inserted and running first" do
      cls = create_job_class
      call_order = []
      expect(described_class).to receive(:insert_job) { call_order << "inserted" }
      fake_client = Sidekiq::Client.new
      expect(fake_client).to(receive(:raw_push)) { call_order << "pushed" }
      expect(Sidekiq::Client).to receive(:new).and_return(fake_client)
      j1 = cls.perform_async
      expect(call_order).to eq(["inserted", "pushed"])
    end
  end

  describe "running the job" do
    it "locks the job when it is being performed" do
      cls = create_job_class(lambda do |w, _args|
        expect(ds1[job_id: w.jid]).to include(
          locked_at: match_time(Time.now).within(5),
          locked_by: be_present,
        )
      end)
      cls.perform_async
      cls.drain
    end

    it "deletes the job after performing" do
      cls = create_job_class(lambda do |w, _args|
        expect(ds1.where(job_id: w.jid).all).to have_length(1)
      end)
      jid = cls.perform_async
      cls.drain
      expect(ds1.where(job_id: jid).all).to be_empty
    end

    it "can find the job in another database" do
      cls = create_job_class(lambda do |w, _args|
        expect(ds1.where(job_id: w.jid).all).to have_length(1)
      end)
      jid = cls.perform_async
      described_class.storage_databases.reverse!
      cls.drain
      expect(ds1.where(job_id: jid).all).to be_empty
    end

    it "unlocks the job on error" do
      cls = create_job_class(lambda do |_w, _args|
        raise NotImplementedError
      end)
      jid = cls.perform_async
      expect { cls.drain }.to raise_error(NotImplementedError)
      expect(ds1[job_id: jid]).to include(locked_by: nil, locked_at: nil)
    end

    it "warns if a job was not locked at the start of performing" do
      cls = create_job_class
      cls.perform_async
      ds1.delete
      expect(Sidekiq.logger).to receive(:error)
      cls.drain
    end
  end

  describe "heartbeat" do
    it "touches the assume_dead_at timestamp" do
      cls = create_job_class(lambda do |w, _args|
        described_class.heartbeat
        expect(ds1[job_id: w.jid]).to include(assume_dead_at: match_time(5.minutes.from_now).within(10))
        Timecop.freeze(30.minutes.from_now) do
          described_class.heartbeat
        end
        expect(ds1[job_id: w.jid]).to include(assume_dead_at: match_time(35.minutes.from_now).within(10))
      end)
      cls.perform_async
      cls.drain
    end

    it "errors if there is no job in TLS" do
      expect { described_class.heartbeat! }.to raise_error(/but no durable job/)
      expect { described_class.heartbeat }.to_not raise_error
    end
  end

  describe "poll_jobs" do
    fake_queue = Class.new do
      include Enumerable
      def initialize(items)
        @items = items
      end

      def size
        return @items.size
      end

      def each(&)
        return @items.each(&)
      end
    end
    fake_entry = Class.new do
      attr_reader :jid

      def initialize(jid)
        @jid = jid
      end
    end
    fake_record = Class.new(fake_entry) do
      attr_reader :at

      def initialize(jid, at)
        super(jid)
        @at = Time.at(at)
      end
    end

    it "re-enqueues jobs in all databases past their recheck time, that are not in the retry set or their queue" do
      cls = create_job_class
      expect(ds1.select_map(:job_id)).to be_empty
      described_class.insert_job(cls, "job1", {"class" => cls, "args" => []})
      described_class.insert_job(cls, "job2", {"class" => cls, "args" => []})
      described_class.insert_job(cls, "job3", {"class" => cls, "args" => []})
      described_class.lock_job("job1", -1)
      described_class.lock_job("job2", 2.minutes)
      expect(cls.jobs).to be_empty
      expect(ds1.select_map(:job_id)).to contain_exactly("job1", "job2", "job3")

      expect(Sidekiq::RetrySet).to receive(:new).once.and_return(fake_queue.new([]))
      expect(Sidekiq::DeadSet).to receive(:new).once.and_return(fake_queue.new([]))
      expect(Sidekiq::Queue).to receive(:new).with("default").once.and_return(fake_queue.new([]))
      described_class.poll_jobs
      # And the row for the polled job is updated
      expect(ds1.select_map(:job_id)).to contain_exactly("job1", "job2", "job3")
      expect(ds1[job_id: "job1"]).to include(assume_dead_at: match_time(5.minutes.from_now).within(10))
      # But the others were not
      expect(ds1[job_id: "job2"]).to include(assume_dead_at: match_time(2.minutes.from_now).within(10))
      # Assert a new job gets enqueued
      expect(cls.jobs).to contain_exactly(
        include("args" => [], "class" => "DurableJob::TestWorker", "jid" => "job1"),
      )
    end

    it "skips checking if retryset is too full" do
      cls = create_job_class
      described_class.insert_job(cls, "job1", {"class" => cls, "args" => []})
      described_class.lock_job("job1", -1)
      expect(cls.jobs).to be_empty
      expect(Sidekiq::RetrySet).to receive(:new).once.and_return(fake_queue.new([]))
      described_class.poll_jobs(skip_queue_size: 0)
      expect(ds1[job_id: "job1"]).to include(assume_dead_at: match_time(-1.seconds.from_now).within(10))
      expect(cls.jobs).to be_empty
    end

    it "skips checking if deadset is too full" do
      cls = create_job_class
      described_class.insert_job(cls, "job1", {"class" => cls, "args" => []})
      described_class.lock_job("job1", -1)
      expect(cls.jobs).to be_empty
      expect(Sidekiq::RetrySet).to receive(:new).once.
        and_return(fake_queue.new([]))
      expect(Sidekiq::DeadSet).to receive(:new).once.
        and_return(fake_queue.new([fake_record.new("j123", Time.now)]))
      described_class.poll_jobs(skip_queue_size: 1)
      expect(ds1[job_id: "job1"]).to include(assume_dead_at: match_time(-1.seconds.from_now).within(10))
      expect(cls.jobs).to be_empty
    end

    it "skips checking jobs in queues that are too full" do
      cls = create_job_class
      described_class.insert_job(cls, "job1", {"class" => cls, "args" => []}, more: {queue: "q1"})
      described_class.insert_job(cls, "job2", {"class" => cls, "args" => []}, more: {queue: "q1"})
      described_class.insert_job(cls, "job3", {"class" => cls, "args" => []}, more: {queue: "q2"})
      described_class.lock_job("job1", -1)
      described_class.lock_job("job2", -1)
      described_class.lock_job("job3", -1)
      expect(Sidekiq::RetrySet).to receive(:new).once.and_return(fake_queue.new([]))
      expect(Sidekiq::DeadSet).to receive(:new).once.and_return(fake_queue.new([]))
      expect(Sidekiq::Queue).to receive(:new).with("q1").
        and_return(fake_queue.new([fake_entry.new("job4"), fake_entry.new("job5")]))
      expect(Sidekiq::Queue).to receive(:new).with("q2").
        and_return(fake_queue.new([fake_entry.new("job3")]))
      described_class.poll_jobs(skip_queue_size: 2)
      expect(ds1.select_map(:job_id)).to contain_exactly("job1", "job2", "job3")
      # jobs 1 and 2, in q1, should not have been updated or enqueued since q1 is full.
      # The q2 job is updated because the queue is not busy.
      # But because it's already in its queue, it isn't re-enqueued
      expect(ds1[job_id: "job1"]).to include(assume_dead_at: match_time(-1.seconds.ago).within(10))
      expect(ds1[job_id: "job3"]).to include(assume_dead_at: match_time(5.minutes.from_now).within(10))
      expect(cls.jobs).to be_empty
    end

    it "uses the retry time for items in the retry set" do
      cls = create_job_class
      described_class.insert_job(cls, "job1", {"class" => cls, "args" => []})
      described_class.insert_job(cls, "job2", {"class" => cls, "args" => []})
      described_class.lock_job("job1", -1)
      expect(Sidekiq::RetrySet).to receive(:new).once.
        and_return(fake_queue.new([fake_record.new("job1", 3.days.from_now.to_f)]))
      expect(Sidekiq::DeadSet).to receive(:new).once.and_return(fake_queue.new([]))
      expect(Sidekiq::Queue).to receive(:new).with("default").once.and_return(fake_queue.new([]))
      expect(cls.jobs).to be_empty
      described_class.poll_jobs
      # The row for the polled job is updated
      expect(ds1[job_id: "job1"]).to include(assume_dead_at: match_time((3.days + 5.minutes).from_now).within(10))
      # No job gets enqueued, since it is already in the retry set
      expect(cls.jobs).to be_empty
    end

    it "deletes the job if it is found in the deadset" do
      cls = create_job_class
      described_class.insert_job(cls, "job1", {"class" => cls, "args" => []})
      described_class.lock_job("job1", -1)
      expect(Sidekiq::RetrySet).to receive(:new).once.and_return(fake_queue.new([]))
      expect(Sidekiq::DeadSet).to receive(:new).once.
        and_return(fake_queue.new([fake_record.new("job1", Time.at(0))]))
      expect(Sidekiq::Queue).to receive(:new).with("default").once.and_return(fake_queue.new([]))
      described_class.poll_jobs
      expect(ds1.all).to be_empty
      expect(cls.jobs).to be_empty
    end
  end

  describe "database_setting" do
    before(:each) do
      @orig_settings = described_class.instance_variable_get(:@database_settings)
      described_class.instance_variable_set(:@database_settings, {})
    end

    after(:each) do
      described_class.instance_variable_set(:@database_settings, @orig_settings)
    end

    it "sets on the current dbs and maintains across reloads" do
      orig_db = described_class.storage_databases.first
      logger = Logger.new(File::NULL)
      described_class.set_database_setting(:loggers, [logger])
      expect(orig_db.loggers).to contain_exactly(logger)

      described_class.reset_configuration
      new_db = described_class.storage_databases.first
      expect(new_db).to_not eq(orig_db)
      expect(new_db.loggers).to contain_exactly(logger)
    end

    it "can replace all settings" do
      described_class.reset_configuration
      orig_db = described_class.storage_databases.first
      # Initial value
      expect(orig_db).to have_attributes(log_warn_duration: nil)
      # Ensure it gets proxied
      described_class.set_database_setting(:log_warn_duration, 1)
      expect(orig_db).to have_attributes(log_warn_duration: 1)
      # Replace fields. Old log warn duration is replaced.
      described_class.replace_database_settings({sql_log_level: :error})
      # This original instance is not modified; the new one is
      expect(orig_db).to have_attributes(log_warn_duration: 1, sql_log_level: :info)
      expect(described_class.storage_databases.first).to have_attributes(log_warn_duration: nil, sql_log_level: :error)

      described_class.reset_configuration
      new_db = described_class.storage_databases.first
      expect(new_db).to_not eq(orig_db)
      # log warn time should have been reset, but log level persisted
      expect(new_db).to have_attributes(log_warn_duration: nil, sql_log_level: :error)
    end
  end
end
