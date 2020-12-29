# frozen_string_literal: true

RSpec.describe Appydays::Dotenviable do
  it "loads env files using RACK_ENV" do
    expect(Dotenv).to receive(:load).with(".env.foo.local", ".env.foo", ".env")
    described_class.load(env: {"RACK_ENV" => "foo"})
  end

  it "loads env files using the explicit env" do
    expect(Dotenv).to receive(:load).with(".env.bar.local", ".env.bar", ".env")
    described_class.load(rack_env: "bar")
  end

  it "loads env files with the given default env if no RACK_ENV is defined" do
    expect(Dotenv).to receive(:load).with(".env.bar.local", ".env.bar", ".env")
    described_class.load(default_rack_env: "bar", env: {})
  end

  it "loads env files with RACK_ENV rather than the default, if RACK_ENV is defined" do
    expect(Dotenv).to receive(:load).with(".env.bar.local", ".env.bar", ".env")
    described_class.load(default_rack_env: "foo", env: {"RACK_ENV" => "bar"})
  end

  it "reapplies the original port if one was not loaded" do
    env = {"PORT" => "123"}
    expect(Dotenv).to receive(:load)
    described_class.load(env: env)
    expect(env).to include("PORT" => "123")
  end

  it "does not reapply the original port if one was loaded" do
    env = {"PORT" => "123"}
    expect(Dotenv).to receive(:load) { env["PORT"] = "456" }
    described_class.load(env: env)
    expect(env).to include("PORT" => "456")
  end
end
