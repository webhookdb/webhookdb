# frozen_string_literal: true

require "webhookdb/envfixer"

RSpec.describe Webhookdb::Envfixer do
  describe "replace_localhost_for_docker" do
    let(:env) do
      {
        "LHURL" => "http://localhost:123/foo",
        "LH" => "localhost",
        "URL" => "https://notlocalhost/",
      }
    end

    it "replaces localhost urls" do
      env["DOCKER_DEV"] = ""
      described_class.replace_localhost_for_docker(env)
      expect(env).to eq({
                          "LHURL" => "http://host.docker.internal:123/foo",
                          "LH" => "localhost",
                          "URL" => "https://notlocalhost/",
                          "DOCKER_DEV" => "",
                        })
    end

    it "noops if DOCKER_DEV is not set" do
      expect do
        described_class.replace_localhost_for_docker(env)
      end.to_not(change { env })
    end
  end

  describe "merge_heroku_env" do
    let(:env) do
      {
        "X" => "1",
        "Y" => "10",
      }
    end

    it "merges heroku env from the given app" do
      env["MERGE_HEROKU_ENV"] = "sushi"
      allow(described_class).to receive(:`).
        with("heroku config -j --app=sushi").
        and_return({"X" => "2", "Z" => "3"}.to_json)
      described_class.merge_heroku_env(env)
      expect(env).to eq({"MERGE_HEROKU_ENV" => "sushi", "X" => "2", "Y" => "10", "Z" => "3"})
    end

    it "noops if MERGE_HEROKU_ENV is not set" do
      expect do
        described_class.merge_heroku_env(env)
      end.to_not(change { env })
    end
  end
end
