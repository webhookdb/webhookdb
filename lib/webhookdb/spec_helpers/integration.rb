# frozen_string_literal: true

require "appydays/configurable"
require "httparty"
require "rspec"

require "webhookdb"
require "webhookdb/async"

raise "integration tests not enabled, this file should not have been evaluated" unless
  Webhookdb::INTEGRATION_TESTS_ENABLED

module Webhookdb::IntegrationSpecHelpers
  include Appydays::Configurable
  include Appydays::Loggable

  def self.included(context)
    context.before(:each) do |example|
      raise "Unit tests should not be run during integration tests (or this test needs an :integration flag" unless
        example.metadata[:integration]

      @to_destroy = []
      WebMock.allow_net_connect!
    end

    context.after(:each) do
      @to_destroy.each(&:destroy)
      WebMock.disable_net_connect!
    end
    super
  end

  module_function def with_async_publisher
    Amigo.install_amigo_jobs
    yield
  ensure
    Amigo.subscribers.clear
  end

  module_function def url(more)
    return "#{Webhookdb.api_url}#{more}"
  end

  module_function def parse_cookie(resp)
    cookie_hash = HTTParty::CookieHash.new
    resp.get_fields("Set-Cookie")&.each { |c| cookie_hash.add_cookies(c) }
    return cookie_hash
  end

  module_function def store_cookies
    response = yield()
    @stored_cookies = parse_cookie(response)
    Webhookdb::IntegrationSpecHelpers.logger.debug "Got cookies: %p" % [stored_cookies]
    return response
  end

  module_function def stored_cookies
    return @stored_cookies
  end

  module_function def auth_customer(customer=nil)
    if customer.nil?
      customer = Webhookdb::Fixtures.customer.instance
      resp = post("/v1/auth", body: {email: customer.email})
      expect(resp).to party_status(202)
      customer = Webhookdb::Customer[email: customer.email]
    end

    code = Webhookdb::Fixtures.reset_code(customer:).create
    resp = post("/v1/auth", body: {email: customer.email, token: code.token})
    expect(resp).to party_status(200)

    return customer.refresh
  end

  [:get, :post, :put, :patch, :delete].each do |method|
    define_method(method) do |url_, opts={}|
      opts[:headers] ||= {}
      store_cookies do
        cookie_header = stored_cookies&.to_cookie_string
        opts[:headers] = opts[:headers].merge("Cookie" => cookie_header) if cookie_header.present?
        if opts.delete(:json)
          opts[:headers]["Content-Type"] = "application/json"
          opts[:body] = opts[:body].to_json unless opts[:body].is_a?(String)
        end
        Webhookdb::IntegrationSpecHelpers.logger.info "%s %s %s" % [method.upcase, url_, opts]
        HTTParty.send(method, url(url_), opts)
      end
    end
    module_function method
  end
end

# Check that an HTTParty::Response code matches the expected.
RSpec::Matchers.define(:party_status) do |expected_status|
  match do |response|
    response.code == expected_status
  end

  failure_message do |response|
    "expected response code %d, got a %d response instead\nBody: %s" %
      [expected_status, response.code, response.parsed_response]
  end
end

# Match a parsed Response hash (deep symbol keys) against an RSpec matcher.
RSpec::Matchers.define(:party_response) do |matcher|
  match do |response|
    matcher.matches?(response.parsed_response.deep_symbolize_keys)
  end

  failure_message do
    matcher.failure_message
  end
end
