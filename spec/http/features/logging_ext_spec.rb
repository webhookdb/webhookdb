# frozen_string_literal: true

require "http"
require "http/features/logging_ext"

RSpec.describe HTTP::Features::LoggingExt do
  logger = SemanticLogger["http_spec_loggingext_mw_test"]

  it "logs at the given level" do
    req = stub_request(:get, "https://example.com/").
      to_return(status: 200, body: "foo", headers: {"H1" => "Val"})
    logs = capture_logs_from(logger, level: :info, formatter: :json) do
      HTTP.use(logging_ext: {logger:, level: :warn}).get("https://example.com/")
    end
    expect(req).to have_been_made
    expect(logs.map { |j| JSON.parse(j) }).to contain_exactly(
      include(
        "context" => {
          "http_method" => "GET",
          "http_url" => "https://example.com/",
        },
        "level" => "warn",
        "message" => "http_request",
      ),
      include(
        "context" => {"http_response_status" => 200},
        "level" => "warn",
        "message" => "http_response",
      ),
    )
  end

  it "can dump request and response" do
    req = stub_request(:get, "https://example.com/").
      to_return(status: 200, body: "foo", headers: {"H1" => "Val"})
    logs = capture_logs_from(logger, formatter: :json) do
      HTTP.use(logging_ext: {logger:, dump_request: true, dump_response: true}).get("https://example.com/")
    end
    expect(req).to have_been_made
    expect(logs.map { |j| JSON.parse(j) }).to contain_exactly(
      include("message" => "http_request"),
      include(
        "context" => {
          "http_request_body" => nil,
          "http_request_headers" => include("Host" => "example.com"),
        },
        "level" => "debug",
        "message" => "http_request_debug",
      ),
      include("message" => "http_response"),
      include(
        "context" => {
          "http_response_body" => "foo",
          "http_response_headers" => {"H1" => "Val"},
        },
        "level" => "debug",
        "message" => "http_response_debug",
      ),
    )
  end

  it "can skip request and response dumps" do
    req = stub_request(:get, "https://example.com/").
      to_return(status: 200, body: "foo", headers: {"H1" => "Val"})
    logs = capture_logs_from(logger, formatter: :json) do
      HTTP.use(logging_ext: {logger:, dump_request: false, dump_response: false}).get("https://example.com/")
    end
    expect(req).to have_been_made
    expect(logs.map { |j| JSON.parse(j) }).to contain_exactly(
      include("message" => "http_request"),
      include("message" => "http_response"),
    )
  end
end
