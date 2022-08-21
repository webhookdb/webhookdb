# frozen_string_literal: true

require "httparty"

module Webhookdb::Http
  # Error raised when some API has rate limited us.
  class BaseError  < StandardError; end

  class Error < BaseError
    attr_reader :response, :body, :uri, :status

    def initialize(response, msg=nil)
      @response = response
      @body = response.body
      @headers = response.headers.to_h
      @status = response.code
      @uri = response.request.last_uri.dup
      if @uri.query.present?
        cleaned_params = CGI.parse(@uri.query).map { |k, v| k.include?("secret") ? [k, ".snip."] : [k, v] }
        @uri.query = HTTParty::Request::NON_RAILS_QUERY_STRING_NORMALIZER.call(cleaned_params)
      end
      super(msg || self.to_s)
    end

    def to_s
      return "HttpError(status: #{self.status}, uri: #{self.uri}, body: #{self.body})"
    end

    alias inspect to_s
  end

  def self.user_agent
    return Webhookdb.http_user_agent unless Webhookdb.http_user_agent.blank?
    return "WebhookDB/#{Webhookdb::RELEASE} https://webhookdb.com #{Webhookdb::RELEASE_CREATED_AT}"
  end

  def self.check!(response, **options)
    # All oks are ok
    return if response.code < 300
    # We expect 300s if we aren't following redirects
    return if response.code < 400 && !options[:follow_redirects]
    # Raise for 400s, or 300s if we were meant to follow redirects
    raise Error, response
  end

  def self.get(url, query={}, **options)
    raise ArgumentError, "must pass :logger keyword" unless options.key?(:logger)
    opts = {query:, headers: {}}.merge(**options)
    opts[:headers]["User-Agent"] = self.user_agent
    r = HTTParty.get(url, **opts)
    self.check!(r, **opts)
    return r
  end

  def self.post(url, body={}, headers: {}, **options)
    raise ArgumentError, "must pass :logger keyword" unless options.key?(:logger)
    headers["Content-Type"] ||= "application/json"
    headers["User-Agent"] = self.user_agent
    body = body.to_json if !body.is_a?(String) && headers["Content-Type"].include?("json")
    opts = {body:, headers:}.merge(**options)
    r = HTTParty.post(url, **opts)
    self.check!(r, **options)
    return r
  end
end
