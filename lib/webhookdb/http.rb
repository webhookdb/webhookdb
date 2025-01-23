# frozen_string_literal: true

require "appydays/configurable"
require "appydays/loggable/httparty_formatter"
require "down/httpx"
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

  # Convenience wrapper around Down so we can use our preferred implementation.
  # See commit history for more info.
  # @return Array<Down::ChunkedIO, IO> Tuple
  def self.chunked_download(request_url, rewindable: false, **down_kw)
    uri = URI(request_url)
    raise URI::InvalidURIError, "#{request_url} must be an http/s url" unless ["http", "https"].include?(uri.scheme)
    down_kw[:headers] ||= {}
    down_kw[:headers]["User-Agent"] ||= self.user_agent
    io = Down::Httpx.open(uri, rewindable:, **down_kw)
    return io
  end
end

class Down::Httpx
  alias _original_response_error! response_error!
  def response_error!(response)
    # For some reason, Down's httpx backend uses TooManyRedirects for every status code...
    raise Down::NotModified if response.status == 304
    return self._original_response_error!(response)
  end
end

class HTTPX::Response::Body
  alias _original_initialize initialize
  def initialize(*)
    _original_initialize(*)
    # If the encoding is an invalid one like 'utf8' vs 'utf-8', modify what's was in the charset.
    # See https://github.com/HoneyryderChuck/httpx/issues/66
    return unless @encoding.is_a?(String) && (md = @encoding.match(/^(utf)(\d+)$/))
    @encoding = "#{md[1]}-#{md[2]}"
  end
end

# Not sure why, but Down uses this, loads the plugin, but the constant isn't defined.
require "httpx/plugins/follow_redirects"
