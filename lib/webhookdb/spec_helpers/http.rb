# frozen_string_literal: true

require "puma"
require "webmock"

module Webhookdb::SpecHelpers::Http
end

module Webhookdb::SpecHelpers::Http::TestServer
  class << self
    def test_server_responses = @test_server_responses ||= []
    def test_server_calls = @test_server_calls ||= []
  end

  def self.included(c)
    test_server_port = nil
    server_thread = nil
    pserver = nil

    c.let(:test_server) { pserver }
    c.let(:test_server_port) { test_server_port }
    c.let(:test_server_responses) { Webhookdb::SpecHelpers::Http::TestServer.test_server_responses }
    c.let(:test_server_calls) { Webhookdb::SpecHelpers::Http::TestServer.test_server_calls }
    c.let(:test_server_url) { "http://localhost:#{test_server_port}" }

    c.before(:all) do
      server = Class.new do
        define_method(:call) do |env|
          resp = Webhookdb::SpecHelpers::Http::TestServer.test_server_responses.pop
          raise "must push to responses" if resp.nil?
          Webhookdb::SpecHelpers::Http::TestServer.test_server_calls << env
          resp = resp.call(env) if resp.respond_to?(:call)
          return resp
        end
      end
      pserver = Puma::Server.new(server.new)
      tcp_server = pserver.add_tcp_listener("127.0.0.1", test_server_port)
      test_server_port = tcp_server.addr[1]
      server_thread = Thread.new do
        pserver.run
      end
      # I don't think we need to sleep here but add it if needed.
    end

    c.after(:all) do
      pserver&.stop(true)
      server_thread&.join
    end

    c.before(:each) do
      WebMock.allow_net_connect!
      WebMock::HttpLibAdapters::HttpRbAdapter.disable!
      Webhookdb::SpecHelpers::Http::TestServer.test_server_responses.clear
      Webhookdb::SpecHelpers::Http::TestServer.test_server_calls.clear
    end

    c.after(:each) do
      WebMock::HttpLibAdapters::HttpRbAdapter.enable!
      WebMock.disable_net_connect!
    end
  end
end
