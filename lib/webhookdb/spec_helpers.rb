# frozen_string_literal: true

require "oj"
require "webhookdb"

RSpec::Matchers.define_negated_matcher(:exclude, :include)
RSpec::Matchers.define_negated_matcher(:not_include, :include)
RSpec::Matchers.define_negated_matcher(:not_change, :change)
RSpec::Matchers.define_negated_matcher(:not_be_nil, :be_nil)
RSpec::Matchers.define_negated_matcher(:not_eq, :eq)
RSpec::Matchers.define_negated_matcher(:not_be_empty, :be_empty)

module Webhookdb::SpecHelpers
  # The directory to look in for fixture data
  TEST_DATA_DIR = Pathname("spec/data").expand_path

  def self.included(context)
    context.before(:all) do
      Webhookdb::Customer.password_hash_cost = 1
    end
    context.before(:each) do
      allow(Kernel).to receive(:sleep) do |n|
        raise "Never sleep with > 0 during tests" if n.positive?
      end
    end
    super
  end

  module_function def test_data_dir
    return TEST_DATA_DIR
  end

  module_function def json_headers(**more)
    return {"Content-Type" => "application/json"}.merge(**more)
  end

  module_function def json_response(body, status: 200, headers: {})
    return {status:, body: body.to_json, headers: json_headers(**headers)}
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
        Oj.load(rawdata)
      when ".yml", ".yaml"
        YAML.safe_load(rawdata)
      else
        rawdata
    end
  end
end
