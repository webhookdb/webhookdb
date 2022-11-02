# frozen_string_literal: true

require "amigo/autoscaler"

RSpec.describe Amigo::Autoscaler do
  def instance(**kw)
    described_class.new(poll_interval: 0, handlers: ["test"], **kw)
  end

  before(:all) do
    @dyno = ENV.fetch("DYNO", nil)
  end

  after(:each) do
    ENV["DYNO"] = @dyno
  end

  describe "start" do
    it "starts a polling thread if the dyno env var matches the given regex" do
      ENV["DYNO"] = "foo.123"
      o = instance(hostname_regex: /^foo\.123$/)
      expect(o.start).to be_truthy
      expect(o.polling_thread).to be_a(Thread)
      o.polling_thread.kill

      o = instance
      ENV["DYNO"] = "foo.12"
      expect(o.start).to be_falsey
      expect(o.polling_thread).to be_nil
    end

    it "starts a polling thread if the hostname matches the given regex" do
      expect(Socket).to receive(:gethostname).and_return("foo.123")
      o = instance(hostname_regex: /^foo\.123$/)
      expect(o.start).to be_truthy
      expect(o.polling_thread).to be_a(Thread)
      o.polling_thread.kill

      expect(Socket).to receive(:gethostname).and_return("foo.12")
      o = instance
      expect(o.start).to be_falsey
      expect(o.polling_thread).to be_nil
    end
  end

  describe "check" do
    def fake_q(name, latency)
      cls = Class.new do
        define_method(:name) { name }
        define_method(:latency) { latency }
      end
      return cls.new
    end

    it "noops if there are no high latency queues" do
      expect(Sidekiq::Queue).to receive(:all).and_return([fake_q("x", 1)])
      o = instance
      expect(o).to_not receive(:alert_test)
      o.setup
      o.check
    end

    it "alerts about high latency queues" do
      expect(Sidekiq::Queue).to receive(:all).and_return([fake_q("x", 1), fake_q("y", 20)])
      o = instance
      expect(o).to receive(:alert_test).with({"y" => 20})
      o.setup
      o.check
    end

    it "noops if recently alerted" do
      expect(Sidekiq::Queue).to receive(:all).
        twice.
        and_return([fake_q("x", 1), fake_q("y", 20)])
      now = Time.now
      o = instance(poll_interval: 2.minutes.to_i)
      o.setup
      expect(o).to receive(:alert_test).twice
      Timecop.freeze(now) { o.check }
      Timecop.freeze(now + 1.minute) { o.check }
      Timecop.freeze(now + 3.minutes) { o.check }
    end
  end

  describe "alert_log" do
    after(:each) do
      Amigo.reset_logging
    end

    it "logs" do
      Amigo.structured_logging = true
      expect(Amigo.log_callback).to receive(:[]).
        with(nil, :warn, "high_latency_queues", {queues: {"x" => 11, "y" => 24}})
      instance.alert_log({"x" => 11, "y" => 24})
    end
  end

  describe "alert_sentry" do
    before(:each) do
      @main_hub = Sentry.get_main_hub
      Sentry.init do |config|
        config.dsn = "http://public:secret@not-really-sentry.nope/someproject"
      end
    end

    after(:each) do
      Sentry.instance_variable_set(:@main_hub, nil)
    end

    it "calls Sentry" do
      expect(Sentry.get_current_client).to receive(:capture_event).
        with(
          have_attributes(message: "Some queues have a high latency: x, y"),
          have_attributes(extra: {high_latency_queues: {"x" => 11, "y" => 24}}),
          include(:message),
        )
      instance.alert_sentry({"x" => 11, "y" => 24})
    end
  end
end
