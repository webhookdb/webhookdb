# frozen_string_literal: true

module Webhookdb::Http
  # Error raised when some API has rate limited us.
  class BaseError < RuntimeError; end

  class Error < BaseError
    attr_reader :response, :body, :uri, :status

    def initialize(response, msg=nil)
      @response = response
      @body = response.body
      @headers = response.headers.to_h
      @uri = response.request.last_uri
      @status = response.code
      super(msg || self.to_s)
    end

    def to_s
      return "HttpError(status: #{self.status}, uri: #{self.uri}, body: #{self.body})"
    end

    alias inspect to_s
  end

  def self.user_agent
    return "WebhookDB/#{Webhookdb::RELEASE} https://webhookdb.com #{Webhookdb::RELEASE_CREATED_AT}"
  end

  def self.check!(response)
    return if response.ok?
    raise Error, response
  end

  def self.get(url, query={}, **options)
    raise ArgumentError, "must pass :logger keyword" unless options.key?(:logger)
    opts = {query: query, headers: {}}.merge(**options)
    opts[:headers]["User-Agent"] = self.user_agent
    r = HTTParty.get(url, **opts)
    self.check!(r)
    return r
  end

  def self.post(url, body={}, headers: {}, **options)
    raise ArgumentError, "must pass :logger keyword" unless options.key?(:logger)
    headers["Content-Type"] ||= "application/json"
    headers["User-Agent"] = self.user_agent
    opts = {body: body, headers: headers}.merge(**options)
    r = HTTParty.post(url, **opts)
    self.check!(r)
    return r
  end
end
