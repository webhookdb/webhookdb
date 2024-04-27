# frozen_string_literal: true

require "webhookdb/errors"

RSpec.describe Webhookdb::Errors do
  wrapped_ex = Class.new(StandardError) do
    attr_accessor :wrapped, :cause

    def initialize(msg, cause, wrapped)
      super(msg)
      self.cause = cause
      self.wrapped = wrapped
    end
  end

  describe "each_cause" do
    it "walks nested causes and wrapped exceptions" do
      e = wrapped_ex.new(
        "a",
        wrapped_ex.new(
          "b",
          wrapped_ex.new("c", nil, nil),
          wrapped_ex.new("d", nil, nil),
        ),
        wrapped_ex.new(
          "l",
          nil,
          wrapped_ex.new("m", wrapped_ex.new("n", nil, nil), nil),
        ),
      )
      r = []
      described_class.each_cause(e) { |ex| r << ex }
      expect(r.map(&:message)).to eq(["a", "b", "c", "d", "l", "m", "n"])
    end

    it "stops walking if true is returned" do
      e = wrapped_ex.new(
        "a",
        wrapped_ex.new(
          "b",
          wrapped_ex.new("c", nil, nil),
          wrapped_ex.new("d", nil, nil),
        ),
        nil,
      )
      r = []
      described_class.each_cause(e) do |ex|
        r << ex
        ex.message == "c"
      end
      expect(r.map(&:message)).to eq(["a", "b", "c"])
    end
  end

  describe "find_cause" do
    it "finds the first exception matching the predicate" do
      e = wrapped_ex.new(
        "a",
        wrapped_ex.new(
          "b",
          wrapped_ex.new("c", nil, nil),
          wrapped_ex.new("d", nil, nil),
        ),
        nil,
      )
      c = described_class.find_cause(e) { |ex| ex.message == "c" }
      expect(c).to have_attributes(message: "c")
    end

    it "returns nil if nothing matches" do
      e = wrapped_ex.new(
        "a",
        wrapped_ex.new(
          "b",
          wrapped_ex.new("c", nil, nil),
          wrapped_ex.new("d", nil, nil),
        ),
        nil,
      )
      c = described_class.find_cause(e) { |ex| ex.message == "f" }
      expect(c).to be_nil
    end
  end
end
