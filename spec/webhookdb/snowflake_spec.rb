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
        ["snowbin", "-o", "friendly=false", "-o", "quiet=true", "--accountname", "a",
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
        ["snowbin", "-o", "friendly=false", "-o", "quiet=true", "--accountname", "a",
         "--username", "u", "--dbname", "d", "--schemaname", "s", "--rolename", "r", "--warehouse", "w",],
      )
      expect(args[1]).to eq({"SNOWSQL_PWD" => "p"})
    end

    it "falls back to the uri" do
      args = described_class.parse_url_to_cli_args("snowflake://u:p@a/d")
      expect(args[0]).to eq(
        ["snowbin", "-o", "friendly=false", "-o", "quiet=true", "--accountname", "a",
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
      described_class.run_cli(described_class.test_url, "SELECT COUNT(1) FROM QUERYCHECKER")
    end

    it "raises errors from Snowflake" do
      expect do
        described_class.run_cli(described_class.test_url, "SELECT COUNT(1) FROM QUERYCHECKER1ff")
      end.to raise_error(/SQL compilation error/)
    end
  end
end
