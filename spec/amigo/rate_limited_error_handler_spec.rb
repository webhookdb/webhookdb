# frozen_string_literal: true

require "amigo/rate_limited_error_handler"

RSpec.describe Amigo::RateLimitedErrorHandler do
  reporter_class = Class.new do
    attr_accessor :reported

    def initialize
      @reported = []
    end

    def call(ex, ctx)
      @reported << [ex, ctx]
    end
  end
  let(:reporter) { reporter_class.new }
  let(:reported) { reporter.reported }

  # Exceptions are mutable (backtrace) so use let
  let(:ex) { RuntimeError.new("const") }

  it "always sends the event if the sample rate is 1" do
    eh = described_class.new(reporter, sample_rate: 1)
    eh.call(ex, {})
    eh.call(ex, {})
    eh.call(ex, {})
    expect(reported).to have_length(3)
  end

  it "sends only the first event if the sample rate is 0" do
    eh = described_class.new(reporter, sample_rate: 0)
    eh.call(ex, {})
    eh.call(ex, {})
    eh.call(ex, {})
    expect(reported).to have_length(1)
  end

  it "skips about half the events after the first if the sample rate is 0.5" do
    eh = described_class.new(reporter, sample_rate: 0.5)
    Array.new(500) { eh.call(ex, {}) }
    expect(reported).to have_length(be < 500)
  end

  it "uses the given ttl for the rate limiting key" do
    now = Time.now
    eh = described_class.new(reporter, sample_rate: 0, ttl: 1.hour)
    Timecop.freeze(now) do
      eh.call(ex, {})
      expect(reported).to have_length(1)
      eh.call(ex, {}) # Immediate call
      expect(reported).to have_length(1)
    end

    Timecop.freeze(now + 59.minutes) { eh.call(ex, {}) }
    expect(reported).to have_length(1) # Still too early

    Timecop.freeze(now + 61.minutes) { eh.call(ex, {}) }
    expect(reported).to have_length(2) # TTL expired
  end

  describe "fingerprint" do
    it "generates unique fingerprints for exception objects" do
      eh = described_class.new(reporter)
      ex1 = RuntimeError.new("ex")
      ex2 = RuntimeError.new("ex")
      # rubocop:disable RSpec/IdenticalEqualityAssertion:
      expect(eh.fingerprint(ex1)).to eq(eh.fingerprint(ex1))
      # rubocop:enable RSpec/IdenticalEqualityAssertion:
      expect(eh.fingerprint(ex2)).to_not eq(eh.fingerprint(ex1))
    end

    it "generates the same fingerprint for exceptions with the same stack traces" do
      eh = described_class.new(reporter)
      fingerprints = Set.new
      Array.new(5) do |x|
        x / 0
      rescue ZeroDivisionError => e
        fingerprints << eh.fingerprint(e)
      end
      expect(fingerprints).to have_attributes(size: 1)

      begin
        1 / 0
      rescue ZeroDivisionError => e
        fingerprints << eh.fingerprint(e)
      end
      expect(fingerprints).to have_attributes(size: 2)
    end

    it "ignores the message of exceptions with a backtrace since the message can be volatile" do
      eh = described_class.new(reporter)
      fingerprints = Set.new
      Array.new(5) do |x|
        nil.send(x.to_sym)
      rescue NoMethodError => e
        fingerprints << eh.fingerprint(e)
      end
      expect(fingerprints).to have_attributes(size: 1)
    end

    it "works with manually raised exceptions" do
      eh = described_class.new(reporter)
      fingerprints = Set.new
      e = RuntimeError.new("t")
      # Raise twice on different lines so there are different stack traces
      begin
        raise e
      rescue RuntimeError => e
        fingerprints << eh.fingerprint(e)
      end
      e.set_backtrace(nil)
      begin
        raise e
      rescue RuntimeError => e
        fingerprints << eh.fingerprint(e)
      end
      expect(fingerprints).to have_attributes(size: 2)
    end

    it "uses unique fingerprints if the same exception has a different cause" do
      eh = described_class.new(reporter)
      fingerprints = Set.new
      # Must have different types, since they are raised with the same stack trace.
      cause1 = TypeError.new("c")
      cause2 = NoMethodError.new("c")
      [cause1, cause2].each do |c|
        begin
          raise c
        rescue StandardError
          raise "wrapped"
        end
      rescue RuntimeError => e
        expect(e).to have_attributes(message: "wrapped", cause: be_present)
        fingerprints << eh.fingerprint(e)
      end
      expect(fingerprints).to have_attributes(size: 2)
    end
  end
end
