# frozen_string_literal: true

# Similar to HTTP::Features::Logging, but uses structured logging
# and can control the level and whether the response body is written.
# :level is what the request/response logs are made at (full dumps are always debug).
#
#    HTTP.use(logging_ext: {logger: Logger.new(STDOUT)}).get("https://example.com/")
#    HTTP.use(logging_ext: {logger:, level: :info}).get("https://example.com/")
#    HTTP.use(logging_ext: {logger:, dump_request: false}).get("https://example.com/")
#    HTTP.use(logging_ext: {logger:, dump_response: false}).get("https://example.com/")
#
class HTTP::Features::LoggingExt < HTTP::Feature
  HTTP::Options.register_feature(:logging_ext, self)

  attr_reader :logger, :level, :dump_request, :dump_response

  def initialize(logger: NullLogger.new, level: :info, dump_request: true, dump_response: true)
    super()
    @logger = logger
    @level = level
    @dump_request = dump_request
    @dump_response = dump_response
  end

  def wrap_request(request)
    self.logger.send(self.level) do
      {message: "http_request", http_method: request.verb.to_s.upcase, http_url: request.uri.to_s}
    end
    if self.dump_request
      self.logger.debug do
        {
          message: "http_request_debug",
          http_request_headers: stringify_headers(request.headers),
          http_request_body: request.body.source,
        }
      end
    end
    request
  end

  def wrap_response(response)
    self.logger.send(self.level) do
      {message: "http_response", http_response_status: response.status}
    end
    if self.dump_response
      self.logger.debug do
        {
          message: "http_response_debug",
          http_response_headers: stringify_headers(response.headers),
          http_response_body: response.body.to_s,
        }
      end
    end
    response
  end

  private def stringify_headers(headers) = headers.to_h { |name, value| [name.to_s, value.to_s] }
end
