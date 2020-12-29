# frozen_string_literal: true

require "webhookdb"
require "yajl"

RSpec::Matchers.define_negated_matcher(:exclude, :include)
RSpec::Matchers.define_negated_matcher(:not_include, :include)
RSpec::Matchers.define_negated_matcher(:not_change, :change)
RSpec::Matchers.define_negated_matcher(:not_be_nil, :be_nil)
RSpec::Matchers.define_negated_matcher(:not_be_empty, :be_empty)

module Webhookdb::SpecHelpers
  # The directory to look in for fixture data
  TEST_DATA_DIR = Pathname("spec/data").expand_path

  def self.included(context)
    context.before(:all) do
      Webhookdb::Customer.password_hash_cost = 1
    end
    super
  end

  ### Load data from the spec/data directory with the specified +name+,
  ### deserializing it if it's YAML or JSON, and returning it.
  module_function def load_fixture_data(name, raw: false)
    name = name.to_s
    path = TEST_DATA_DIR + name
    path = TEST_DATA_DIR + "#{name}.json" unless path.exist? || !File.extname(name).empty?
    path = TEST_DATA_DIR + "#{name}.yaml" unless path.exist? || !File.extname(name).empty?
    path = TEST_DATA_DIR + "#{name}.yml" unless path.exist? || !File.extname(name).empty?

    rawdata = path.read(encoding: "utf-8")

    return rawdata if raw

    return case path.extname
      when ".json"
        Yajl::Parser.parse(rawdata)
      when ".yml", ".yaml"
        YAML.safe_load(rawdata)
      else
        rawdata
    end
  end

  # Zero out nsecs to t can be compared to one from the database.
  module_function def trunc_time(t)
    return t.change(nsec: t.usec * 1000)
  end

  #
  # :section: Matchers
  #

  class HaveALineMatching
    def initialize(regexp)
      @regexp = regexp
    end

    def matches?(target)
      @target = target
      return @target.find do |obj|
        obj.to_s.match(@regexp)
      end
    end

    def failure_message
      return "expected %p to have at least one line matching %p" % [@target, @regexp]
    end

    alias failure_message_for_should failure_message

    def failure_message_when_negated
      return "expected %p not to have any lines matching %p, but it has at least one" % [@target, @regexp]
    end

    alias failure_message_for_should_not failure_message_when_negated
  end

  ### RSpec matcher -- set up the expectation that the lefthand side
  ### is Enumerable, and that at least one of the objects yielded
  ### while iterating matches +regexp+ when converted to a String.
  module_function def have_a_line_matching(regexp)
    return HaveALineMatching.new(regexp)
  end

  module_function def have_length(x)
    return RSpec::Matchers::BuiltIn::HaveAttributes.new(length: x)
  end

  # Matcher that will compare a string or time expected against a string or time actual,
  # within a tolerance (default to 1 millisecond).
  #
  #   expect(last_response).to have_json_body.that_includes(
  #       closes_at: match_time('2025-12-01T00:00:00.000+00:00').within(1.second))
  #
  RSpec::Matchers.define(:match_time) do |expected|
    match do |actual|
      @tolerance ||= 0.001
      RSpec::Matchers::BuiltIn::BeWithin.new(@tolerance).of(self.time(expected)).matches?(self.time(actual))
    end

    failure_message do |actual|
      "expected ids %s to be within %s of %s" % [self.time(actual), @tolerance, self.time(expected)]
    end

    chain :within do |tolerance|
      @tolerance = tolerance
    end

    def time(s)
      return Time.parse(s) if s.is_a?(String)
      return s.to_time
    end
  end

  # Matcher that will compare a string or Money expected against a string or Money actual.
  #
  #   expect(order.total).to cost('$25')
  #
  RSpec::Matchers.define(:cost) do |expected|
    match do |actual|
      @base = RSpec::Matchers::BuiltIn::Eq.new(self.money(expected))
      @base.matches?(self.money(actual))
    end

    failure_message do |_actual|
      @base.failure_message
    end

    def money(s)
      return Monetize.parse(s) if s.is_a?(String)
      return s if s.is_a?(Money)
      return Money.new(s) if s.is_a?(Integer)
      return Money.new(s[:cents], s[:currency]) if s.respond_to?(:key?) && s.key?(:cents) && s.key?(:currency)
      raise "#{s} type #{s.class.name} not convertable to Money (add support or use supported type)"
    end
  end

  # Matcher that will compare a string or Webhookdb::Measure expected against a string or Webhookdb::Measure actual.
  #
  #   expect(value).to weigh('1 lb')
  #   expect([1, :lb]).to weigh(Webhookdb::Measure.parse()'1 lb'))
  #
  RSpec::Matchers.define(:weigh) do |expected|
    match do |actual|
      RSpec::Matchers::BuiltIn::Eq.new(self.measured(expected)).matches?(self.measured(actual))
    end

    failure_message do |actual|
      "expected %s to weigh %s" % [self.measured(actual), self.measured(expected)]
    end

    def measured(s)
      return Webhookdb::Measure.coerce(s)
    end
  end
end
