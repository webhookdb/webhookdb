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

  def poll_jobs(**)
    described_class.poll_jobs(nil, **)
  end

  let(:db1_url) { @db1_url }
  let(:db2_url) { @db2_url }
  let(:db1) { @db1 }
  let(:db2) { @db2 }
  let(:ds1) { @db1[:durable_jobs] }
  let(:ds2) { @db2[:durable_jobs] }

  before(:each) do
    @before_server_mw = Amigo::SpecHelpers::ServerCallbackMiddleware.reset

    Sidekiq.redis(&:flushdb)
    Sidekiq::Testing.disable!
    Sidekiq.default_configuration.server_middleware.add(@before_server_mw)
    Sidekiq.default_configuration.client_middleware.add(described_class::ClientMiddleware)
    Sidekiq.default_configuration.server_middleware.add(described_class::ServerMiddleware)
    described_class.failure_notifier = nil
    @death_handlers = Sidekiq.default_configuration.death_handlers.dup

    described_class.reset_configuration(
      enabled: true,
      server_urls: [db1_url, db2_url],
      server_env_vars: [],
    )
    described_class.storage_datasets.each(&:delete)
  end

  after(:each) do
    Sidekiq.default_configuration.server_middleware.entries.delete(@before_server_mw)
    Sidekiq.default_configuration.client_middleware.remove(described_class::ClientMiddleware)
    Sidekiq.default_configuration.server_middleware.remove(described_class::ServerMiddleware)
    Sidekiq.default_configuration.death_handlers.replace(@death_handlers)
    Sidekiq.redis(&:flushdb)
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
      j1 = cls.set(queue: "myq").perform_async({"x" => 1})
      j2 = cls.perform_in(10.minutes, [1, 2, 3])
      j3 = cls.perform_at(5.minutes.from_now)
      expect(ds1.where(job_id: [j1, j2, j3]).all).to contain_exactly(
        include(
          job_id: j1,
          job_item_json: include('"args":[{"x":1}]').and(include('"class":"DurableJob::TestWorker"')),
          locked_by: nil,
          assume_dead_at: match_time(5.minutes.from_now).within(5),
          queue: "myq",
        ),
        include(
          job_id: j2,
          job_item_json: include('"args":[[1,2,3]]'),
          assume_dead_at: match_time(15.minutes.from_now).within(5),
          queue: "default",
        ),
        include(
          job_id: j3,
          job_item_json: include('"args":[]'),
          assume_dead_at: match_time(10.minutes.from_now).within(5),
          queue: "default",
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

    it "does standard behavior if not enabled" do
      calls = []
      described_class.enabled = false
      cls = create_job_class(->(*) { calls << 1 })
      sidekiq_perform_inline(cls, [])
      expect(calls).to have_length(1)
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
      sidekiq_perform_inline(cls, [])
    end

    it "deletes the job after performing" do
      jid = nil
      cls = create_job_class(lambda do |w, _args|
        expect(ds1.where(job_id: w.jid).all).to have_length(1)
        jid = w.jid
      end)
      sidekiq_perform_inline(cls, [])
      expect(ds1.where(job_id: jid).all).to be_empty
    end

    it "unlocks the job on error" do
      jid = nil
      cls = create_job_class(lambda do |w, _args|
        jid = w.jid
        raise NotImplementedError, "hi"
      end)
      expect { sidekiq_perform_inline(cls, []) }.to raise_error(NotImplementedError)
      row = ds1[job_id: jid]
      expect(row).to include(locked_by: nil, locked_at: nil)
      expect(JSON.parse(row[:job_item_json])).to include(
        "error_class" => "NotImplementedError",
        "error_message" => "hi",
      )
    end

    it "warns if a job was not locked at the start of performing" do
      cls = create_job_class
      @before_server_mw.callback = ->(*) { ds1.delete }
      expect(Sidekiq.logger).to receive(:error).with(/no row found in database/)
      sidekiq_perform_inline(cls, [])
    end

    it "does standard behavior if not enabled" do
      described_class.enabled = false
      expect(described_class).to_not receive(:insert_job)
      cls = create_job_class
      sidekiq_perform_inline(cls, [])
    end

    it "does standard behavior if the job is not a durable job" do
      expect(described_class).to_not receive(:insert_job)
      cls = create_job_class
      cls.instance_exec do
        undef heartbeat_extension
      end
      sidekiq_perform_inline(cls, [])
    end
  end

  describe "insert_job" do
    let(:cls) { create_job_class }

    it "inserts the job" do
      described_class.insert_job(cls, "abc", {})
      expect(ds1).to contain_exactly(
        include(
          assume_dead_at: match_time(cls.heartbeat_extension.from_now).within(5),
          job_class: "DurableJob::TestWorker",
          job_id: "abc", job_item_json: "{\"class\":\"DurableJob::TestWorker\"}",
          locked_at: nil, locked_by: nil,
          queue: "default",
        ),
      )
    end

    it "uses the job 'at' as when the job ran, if present" do
      described_class.insert_job(cls, "abc", {"at" => Time.at(100)})
      expect(ds1).to contain_exactly(
        include(assume_dead_at: match_time("1970-01-01T00:06:40Z")),
      )
    end

    # it "ignores database connection errors" do
    #   # Not sure how ot test this yet
    # end

    it "updates assume_dead_at on insert conflict" do
      described_class.insert_job(cls, "abc", {"at" => Time.at(100)})
      described_class.insert_job(cls, "abc", {"at" => Time.at(10_000)})
      expect(ds1).to contain_exactly(
        include(assume_dead_at: match_time("1970-01-01 02:51:40Z")),
      )
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
      sidekiq_perform_inline(cls, [])
    end

    it "errors if there is no job in TLS" do
      expect { described_class.heartbeat! }.to raise_error(/but no durable job/)
      expect { described_class.heartbeat }.to_not raise_error
    end

    it "noops if not enabled" do
      described_class.enabled = false
      expect do
        described_class.heartbeat
        described_class.heartbeat!
      end.to_not raise_error
    end
  end

  describe "poll_jobs" do
    def all_jobs(q)
      a = q.map { |j| j }
      return a
    end

    it "kills jobs in all databases past their recheck time and missing that are not in queue, retry, or dead set" do
      cls = create_job_class
      expect(ds1.select_map(:job_id)).to be_empty
      described_class.insert_job(cls, "jobx1", {"class" => cls, "args" => []}, more: {missing_at: Time.now})
      described_class.insert_job(cls, "jobx2", {"class" => cls, "args" => []}, more: {missing_at: Time.now})
      described_class.insert_job(cls, "jobx3", {"class" => cls, "args" => []}, more: {missing_at: Time.now})
      described_class.lock_job("jobx1", -1)
      described_class.lock_job("jobx2", 2.minutes)
      expect(all_jobs(Sidekiq::DeadSet.new)).to be_empty
      expect(ds1.select_map(:job_id)).to contain_exactly("jobx1", "jobx2", "jobx3")

      poll_jobs
      # jobx1 has expired so should have moved to the dead set.
      expect(ds1.select_map(:job_id)).to contain_exactly("jobx2", "jobx3")
      expect(all_jobs(Sidekiq::DeadSet.new)).to contain_exactly(
        have_attributes(item: include("args" => [], "class" => "DurableJob::TestWorker", "jid" => "jobx1")),
      )
      # jobx2 and x3 should not have had their deadlines updated since they were found.
      expect(ds1[job_id: "jobx2"]).to include(assume_dead_at: match_time(2.minutes.from_now).within(10))
    end

    def call_recorder
      return Class.new do
        attr_accessor :calls

        def call(*args)
          @calls ||= []
          @calls << args
        end
      end
    end

    it "calls the failure notifier if set" do
      cls = create_job_class
      described_class.insert_job(cls, "jobx1", {"class" => cls, "args" => []}, more: {missing_at: Time.now})
      described_class.lock_job("jobx1", -1)

      fail_rec = call_recorder.new
      death_rec = call_recorder.new
      Sidekiq.default_configuration.death_handlers.replace([death_rec])
      described_class.failure_notifier = fail_rec
      poll_jobs
      expect(fail_rec.calls).to contain_exactly(
        contain_exactly(include("durable_killed_at", "class" => "DurableJob::TestWorker")),
      )
      expect(death_rec.calls).to be_blank
    end

    it "calls death handlers if no failure notifier is set" do
      cls = create_job_class
      described_class.insert_job(cls, "jobx1", {"class" => cls, "args" => []}, more: {missing_at: Time.now})
      described_class.lock_job("jobx1", -1)

      death_rec = call_recorder.new
      Sidekiq.default_configuration.death_handlers.replace([death_rec])
      described_class.failure_notifier = nil
      poll_jobs
      expect(death_rec.calls).to contain_exactly(
        contain_exactly(include("durable_killed_at", "class" => "DurableJob::TestWorker"), be_a(RuntimeError)),
      )
    end

    it "marks jobs as missing, and does not kill them, the first time they cannot be found" do
      cls = create_job_class
      expect(ds1.select_map(:job_id)).to be_empty
      # This job will be marked missing
      described_class.insert_job(cls, "jobx1", {"class" => cls, "args" => []})
      # This job should be deleted, since it's already been marked missing
      described_class.insert_job(cls, "jobx2", {"class" => cls, "args" => []}, more: {missing_at: Time.now})
      described_class.lock_job("jobx1", -1)
      described_class.lock_job("jobx2", -1)

      # The first job will be marked missing, and the second job will be deleted
      poll_jobs
      expect(ds1.all).to contain_exactly(
        include(
          job_id: "jobx1",
          assume_dead_at: match_time(5.minutes.from_now).within(10),
          missing_at: match_time(:now),
        ),
      )
      expect(all_jobs(Sidekiq::DeadSet.new)).to contain_exactly(
        have_attributes(item: include("args" => [], "class" => "DurableJob::TestWorker", "jid" => "jobx2")),
      )
      # Now the first job should die as well on the next poll
      poll_jobs(now: 6.minutes.from_now)
      expect(ds1.all).to be_empty
    end

    it "skips checking if retryset is too full" do
      cls = create_job_class
      described_class.insert_job(cls, "joby1", {"class" => cls, "args" => []}, more: {missing_at: Time.now})
      described_class.lock_job("joby1", -1)
      # Add one to the retry set, so polling skips.
      Sidekiq::RetrySet.new.schedule(Time.now, {})
      poll_jobs(skip_queue_size: 1)
      # Nothing got deleted because we skipped checking with a skip_queue_size of 1.
      expect(ds1[job_id: "joby1"]).to include(assume_dead_at: match_time(-1.seconds.from_now).within(10))
      # But now make sure it got deleted.
      poll_jobs
      expect(ds1[job_id: "joby1"]).to be_nil
    end

    it "skips checking if deadset is too full" do
      cls = create_job_class
      described_class.insert_job(cls, "joby1", {"class" => cls, "args" => []}, more: {missing_at: Time.now})
      described_class.lock_job("joby1", -1)
      # Add one to the dead set, so polling skips.
      Sidekiq::DeadSet.new.kill("{}")
      poll_jobs(skip_queue_size: 1)
      # Nothing got deleted because we skipped checking with a skip_queue_size of 1.
      expect(ds1[job_id: "joby1"]).to include(assume_dead_at: match_time(-1.seconds.from_now).within(10))
      # But now make sure it got deleted.
      poll_jobs
      expect(ds1[job_id: "joby1"]).to be_nil
    end

    it "skips checking jobs in queues that are too full" do
      cls = create_job_class
      j1id = cls.set(queue: "q1").perform_async
      j2id = cls.set(queue: "q1").perform_async
      j3id = cls.set(queue: "q2").perform_async
      described_class.lock_job(j1id, -1)
      described_class.lock_job(j2id, -1)
      described_class.lock_job(j3id, -1)
      expect(ds1.select_map(:job_id)).to contain_exactly(j1id, j2id, j3id)
      poll_jobs(skip_queue_size: 2)
      # jobs 1 and 2, in q1, should not have been updated or enqueued since q1 is full.
      # The q2 job is updated because the queue is not busy so could be checked.
      expect(ds1[job_id: j1id]).to include(assume_dead_at: match_time(-1.seconds.ago).within(10))
      expect(ds1[job_id: j3id]).to include(assume_dead_at: match_time(5.minutes.from_now).within(10))
      expect(all_jobs(Sidekiq::Queue.new("q1"))).to have_length(2)
      expect(all_jobs(Sidekiq::Queue.new("q2"))).to have_length(1)
      expect(all_jobs(Sidekiq::DeadSet.new)).to be_empty
    end

    it "uses the retry time for items in the retry set" do
      cls = create_job_class
      described_class.insert_job(cls, "jobc1", {"class" => cls, "args" => []})
      described_class.insert_job(cls, "jobc2", {"class" => cls, "args" => []})
      described_class.lock_job("jobc1", -1)
      Sidekiq::RetrySet.new.schedule(3.days.from_now.to_f, {"jid" => "jobc1"})
      expect(all_jobs(Sidekiq::Queue.new)).to be_empty
      poll_jobs
      # The row for the polled job is updated
      expect(ds1[job_id: "jobc1"]).to include(assume_dead_at: match_time((3.days + 5.minutes).from_now).within(10))
      # No job gets enqueued, since it is already in the retry set
      expect(all_jobs(Sidekiq::Queue.new)).to be_empty
    end

    it "deletes the job if it is found in the deadset" do
      cls = create_job_class
      described_class.insert_job(cls, "jobc1", {"class" => cls, "args" => []})
      described_class.lock_job("jobc1", -1)
      Sidekiq::DeadSet.new.kill({"jid" => "jobc1"}.to_json)
      poll_jobs
      expect(ds1.all).to be_empty
      expect(all_jobs(Sidekiq::DeadSet.new)).to have_length(1)
    end

    it "noops if not enabled" do
      described_class.enabled = false
      expect(Sidekiq::RetrySet).to_not receive(:new)
      poll_jobs
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

      described_class.reset_configuration(enabled: true)
      new_db = described_class.storage_databases.first
      expect(new_db).to_not eq(orig_db)
      expect(new_db.loggers).to contain_exactly(logger)
    end

    it "can replace all settings" do
      described_class.reset_configuration(enabled: true)
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

      described_class.reset_configuration(enabled: true)
      new_db = described_class.storage_databases.first
      expect(new_db).to_not eq(orig_db)
      # log warn time should have been reset, but log level persisted
      expect(new_db).to have_attributes(log_warn_duration: nil, sql_log_level: :error)
    end
  end
end
