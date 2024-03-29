# frozen_string_literal: true

require "webhookdb/snowflake"

RSpec.describe Webhookdb::Snowflake, :db do
  describe "parse_url_to_cli_args" do
    before(:each) do
      described_class.snowsql = "snowbin"
    end

    after(:each) do
      described_class.reset_configuration
    end

    it "parses exact params" do
      args = described_class.parse_url_to_cli_args("snowflake://?" + {
        accountname: "a",
        username: "u",
        dbname: "d",
        schemaname: "s",
        rolename: "r",
        warehouse: "w",
        password: "p",
      }.to_query)
      expect(args[0]).to eq(
        ["snowbin", "-o", "friendly=false", "-o", "output_format=json", "-o", "timing=false", "--accountname", "a",
         "--username", "u", "--dbname", "d", "--schemaname", "s", "--rolename", "r", "--warehouse", "w",],
      )
      expect(args[1]).to eq({"SNOWSQL_PWD" => "p"})
    end

    it "parses nameless params" do
      args = described_class.parse_url_to_cli_args("snowflake://?" + {
        account: "a",
        user: "u",
        db: "d",
        schema: "s",
        role: "r",
        warehouse: "w",
        password: "p",
      }.to_query)
      expect(args[0]).to eq(
        ["snowbin", "-o", "friendly=false", "-o", "output_format=json", "-o", "timing=false", "--accountname", "a",
         "--username", "u", "--dbname", "d", "--schemaname", "s", "--rolename", "r", "--warehouse", "w",],
      )
      expect(args[1]).to eq({"SNOWSQL_PWD" => "p"})
    end

    it "falls back to the uri" do
      args = described_class.parse_url_to_cli_args("snowflake://u:p@a/d")
      expect(args[0]).to eq(
        ["snowbin", "-o", "friendly=false", "-o", "output_format=json", "-o", "timing=false", "--accountname", "a",
         "--username", "u", "--dbname", "d",],
      )
      expect(args[1]).to eq({"SNOWSQL_PWD" => "p"})
    end

    it "errors if password is missing" do
      expect do
        described_class.parse_url_to_cli_args("snowflake://u@a/d")
      end.to raise_error(ArgumentError, /password/)
    end

    it "errors if required param is missing" do
      expect do
        described_class.parse_url_to_cli_args("snowflake://u:p@a")
      end.to raise_error(ArgumentError, /url requires/)
    end
  end

  describe "run_cli" do
    break unless described_class.run_tests

    it "can connect to the test url" do
      res = described_class.run_cli(described_class.test_url, "SELECT COUNT(1) FROM QUERYCHECKER")
      expect(res).to be_present
    end

    it "can parse json output" do
      res = described_class.run_cli(described_class.test_url, "SELECT 1", parse: true)
      expect(res).to eq([[{"1" => "1"}]])
    end

    it "can parse output that contains json" do
      res = described_class.run_cli(
        described_class.test_url,
        'SELECT parse_json(\'{"x": {"y": 1}}\') as X',
        parse: true,
      )
      expect(res).to eq([[{"X" => "{\n  \"x\": {\n    \"y\": 1\n  }\n}"}]])
    end

    it "can parse output that contains multiple json lines" do
      res = described_class.run_cli(
        described_class.test_url,
        'SELECT parse_json(\'{"x": {"y": 1}}\') AS x;SELECT parse_json(\'{"x": {"y": 1}}\') AS x',
        parse: true,
      )
      expect(res).to eq([[{"X" => "{\n  \"x\": {\n    \"y\": 1\n  }\n}"}],
                         [{"X" => "{\n  \"x\": {\n    \"y\": 1\n  }\n}"}],])
    end

    it "can use a custom parser/format" do
      res = described_class.run_cli(described_class.test_url, "SELECT 1", parse: ->(s) { CSV.parse(s) }, format: "csv")
      expect(res).to eq([["1"], ["1"]])
    end

    it "raises errors from Snowflake" do
      expect do
        described_class.run_cli(described_class.test_url, "SELECT COUNT(1) FROM QUERYCHECKER1ff")
      end.to raise_error(/SQL compilation error/)
    end
  end
end
