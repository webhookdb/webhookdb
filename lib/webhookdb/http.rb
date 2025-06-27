# frozen_string_literal: true

require "appydays/configurable"
require "appydays/loggable/httparty_formatter"
require "http"
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

    def initialize(response, msg=nil, uri: nil, http_method: nil)
      @response = response
      @body = response.body
      @headers = response.headers.to_h
      @status = response.code
      @uri = uri || response.request.last_uri.dup
      if @uri.query.present?
        cleaned_params = CGI.parse(@uri.query).map { |k, v| k.include?("secret") ? [k, ".snip."] : [k, v] }
        @uri.query = HTTParty::Request::NON_RAILS_QUERY_STRING_NORMALIZER.call(cleaned_params)
      end
      @http_method = http_method || response.request.http_method::METHOD
      super(msg || self.to_s)
    end

    def to_s
      return "HttpError(status: #{self.status}, method: #{self.http_method}, uri: #{self.uri}, body: #{self.body})"
    end

    alias inspect to_s
  end

  class ClientError < Error; end
  class ServerError < Error; end
  class NotModified < Error; end
  class TooManyRedirects < BaseError; end

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
    return if response.code <= 299
    raise ServerError, response if response.code >= 500
    raise ClientError, response if response.code >= 400
    # If we followed redirects, we should not see a 300
    raise TooManyRedirects, response if response.code >= 300 && options[:follow_redirects]
    # We got a 300, but are not following redirects, so we're ok.
    return
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

  # Convenience wrapper since downloading a stream isn't so simple.
  # See commit history for more info, including going from Down, to Down/HTTPX, to HTTP.
  # @return [HTTP::Response]
  def self.chunked_download(url, headers: {})
    uri = URI(url)
    raise URI::InvalidURIError, "#{url} must be an http/s url" unless ["http", "https"].include?(uri.scheme)
    headers["User-Agent"] ||= self.user_agent
    headers["Accept"] ||= "*/*"
    headers["Accept-Encoding"] ||= "gzip, deflate"
    begin
      response = HTTP.follow.get(url, headers:)
    rescue HTTP::Redirector::TooManyRedirectsError => e
      raise TooManyRedirects, e
    end
    http_method = response.request.verb
    raise ServerError.new(response, uri:, http_method:) if response.code >= 500
    raise ClientError.new(response, uri:, http_method:) if response.code >= 400
    raise NotModified.new(response, uri:, http_method:) if response.code == 304
    response.body.stream!
    return response
  end

  def self.rewind_request_body(request)
    if request.body.instance_of?(::Rack::Lint::Wrapper::InputWrapper)
      request.body.instance_variable_get(:@input).rewind
    else
      request.body&.rewind
    end
    return request.body
  end
end

class HTTP::Headers
  def fetch(k, *default)
    vals = self.get(k)
    return vals.first unless vals.empty?
    raise KeyError, k if default.empty?
    return default.first
  end
end

class HTTP::Response::Body
  attr_accessor :encoding
end

class HTTP::Response
  alias _orig_initialize initialize
  def initialize(opts)
    # Make how we handle encoding more flexible. Gross but needed for things like icalendar hosts.

    _orig_initialize(opts)

    # If we have an explicit body, don't do anything.
    return if opts.include?(:body)
    # If we have detected a non-default encoding, use it.
    return unless body.encoding == Encoding::BINARY
    # If the charset was invalid, let's try to fix it.
    if charset && (md = charset.match(/^(utf)(\d+)$/))
      body.encoding = Encoding.find("#{md[1]}-#{md[2]}")
      return
    end
    # If we are using a text type, use utf-8.
    if mime_type&.start_with?("text/") || mime_type == "application/json"
      body.encoding = Encoding::UTF_8
      return
    end
    # We can't figure out a better encoding, so use binary.
    return
  end
end
