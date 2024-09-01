# frozen_string_literal: true

require "appydays/configurable"
require "appydays/loggable/httparty_formatter"
require "httparty"

module Webhookdb::Http
  include Appydays::Configurable
  configurable(:http) do
    setting :log_level, :debug
  end

  # Error raised when some API has rate limited us.
  class BaseError < Webhookdb::WebhookdbError; end

  class Error < BaseError
    attr_reader :response, :body, :uri, :status, :http_method

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
      @http_method = response.request.http_method::METHOD
      super(msg || self.to_s)
    end

    def to_s
      return "HttpError(status: #{self.status}, method: #{self.http_method}, uri: #{self.uri}, body: #{self.body})"
    end

    alias inspect to_s
  end

  def self.user_agent
    return Webhookdb.http_user_agent unless Webhookdb.http_user_agent.blank?
    return "WebhookDB/#{Webhookdb::RELEASE} https://webhookdb.com #{Webhookdb::RELEASE_CREATED_AT}"
  end

  def self.extract_url_auth(url)
    parsed_uri = URI(url)
    if parsed_uri.userinfo.present?
      auth_params = {
        username: URI.decode_www_form_component(parsed_uri.user || ""),
        password: URI.decode_www_form_component(parsed_uri.password || ""),
      }
      parsed_uri.user = parsed_uri.password = nil
      cleaned_url = parsed_uri.to_s
      return cleaned_url, auth_params
    end
    return url, nil
  end

  def self.check!(response, **options)
    # All oks are ok
    return if response.code < 300
    # We expect 300s if we aren't following redirects
    return if response.code < 400 && !options[:follow_redirects]
    # Raise for 400s, or 300s if we were meant to follow redirects
    raise Error, response
  end

  def self.get(url, query={}, **options, &)
    self._setup_required_args(options)
    opts = {query:, headers: {}}.merge(**options)
    opts[:headers]["User-Agent"] = self.user_agent
    # See https://github.com/jnunemaker/httparty/issues/784#issuecomment-1585714745
    # I *think* this should be safe to always use.
    opts[:headers]["Connection"] ||= "keep-alive"
    r = HTTParty.get(url, **opts, &)
    self.check!(r, **opts)
    return r
  end

  def self.post(url, body={}, headers: {}, method: nil, check: true, **options, &)
    self._setup_required_args(options)
    headers["Content-Type"] ||= "application/json"
    headers["User-Agent"] = self.user_agent
    body = body.to_json if !body.is_a?(String) && headers["Content-Type"].include?("json")
    opts = {body:, headers:}.merge(**options)
    r = HTTParty.send(method || :post, url, **opts, &)
    self.check!(r, **options) if check
    return r
  end

  def self._setup_required_args(options)
    raise ArgumentError, "must pass :timeout keyword" unless options.key?(:timeout)

    raise ArgumentError, "must pass :logger keyword" unless options.key?(:logger)
    options[:log_format] = :appydays
    options[:log_level] = self.log_level
  end

  # Convenience wrapper around Down that handles gzip.
  # @return Array<Down::ChunkedIO, IO> Tuple
  def self.chunked_download(request_url, rewindable: false, **down_kw)
    io = Down::NetHttp.open(request_url, rewindable:, **down_kw)
    if io.data[:headers].fetch("Content-Encoding", "").include?("gzip")
      # If the response is gzipped, Down doesn't handle it properly.
      # Wrap it with gzip reader, and force the encoding to binary
      # the server may send back a header like Content-Type: text/plain; UTF-8,
      # so each line Down yields via #gets will have force_encoding('utf-8').
      # https://github.com/janko/down/issues/87
      io.instance_variable_set(:@encoding, "binary")
      io = Zlib::GzipReader.wrap(io)
    end
    return io
  end

  def self.gzipped?(string)
    return false if string.length < 3
    b = string[..2].bytes
    return b[0] == 0x1f && b[1] == 0x8b
  end
end
