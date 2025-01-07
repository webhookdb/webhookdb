# frozen_string_literal: true

require "webhookdb/http"

RSpec.describe Webhookdb::Http do
  describe "extract_url_auth" do
    it "returns url and no basic auth params when url has no auth info" do
      cleaned_url, auth_params = described_class.extract_url_auth("https://a.b")
      expect(cleaned_url).to eq("https://a.b")
      expect(auth_params).to be_nil
    end

    it "returns cleaned url and decoded basic auth params when url has auth info" do
      cleaned_url, auth_params = described_class.extract_url_auth("https://leonora%40x.com:pw@a.b")
      expect(cleaned_url).to eq("https://a.b")
      expect(auth_params).to eq({username: "leonora@x.com", password: "pw"})
    end
  end

  describe "get" do
    it "calls HTTP GET" do
      req = stub_request(:get, "https://a.b").to_return(status: 200, body: "")
      qreq = stub_request(:get, "https://x.y/?x=1").to_return(status: 200, body: "")
      described_class.get("https://a.b", logger: nil, timeout: nil)
      described_class.get("https://x.y", {x: 1}, logger: nil, timeout: nil)
      expect(req).to have_been_made
      expect(qreq).to have_been_made
    end

    it "requires a :timeout" do
      expect { described_class.get("https://x.y") }.to raise_error(ArgumentError, "must pass :timeout keyword")
    end

    it "requires a :logger" do
      expect do
        described_class.get("https://x.y", timeout: nil)
      end.to raise_error(ArgumentError, "must pass :logger keyword")
    end

    it "passes through options and merges headers" do
      req = stub_request(:get, "https://a.b/").
        with(
          headers: {
            "Abc" => "123",
            "Authorization" => "Basic dTpw",
            "User-Agent" => "WebhookDB/unknown-release https://webhookdb.com 1970-01-01T00:00:00Z",
          },
        ).
        to_return(status: 200, body: "", headers: {})
      described_class.get(
        "https://a.b",
        logger: nil, timeout: nil,
        headers: {"ABC" => "123"},
        basic_auth: {username: "u", password: "p"},
      )
      expect(req).to have_been_made
    end

    it "errors on non-ok" do
      stub_request(:get, "https://a.b/").
        to_return(status: 500, body: "meh")

      expect { described_class.get("https://a.b", logger: nil, timeout: nil) }.to raise_error(described_class::Error)
    end

    it "does not error for 300s if not following redirects" do
      req = stub_request(:get, "https://a.b").to_return(status: 307, headers: {location: "https://x.y"})
      resp = described_class.get("https://a.b", logger: nil, timeout: nil, follow_redirects: false)
      expect(req).to have_been_made
      expect(resp).to have_attributes(code: 307)
    end

    it "passes through a block" do
      req = stub_request(:get, "https://a.b").to_return(status: 200, body: "abc")
      t = +""
      described_class.get("https://a.b", logger: nil, timeout: nil) do |f|
        t << f
      end
      expect(req).to have_been_made
      expect(t).to eq("abc")
    end
  end

  describe "post" do
    it "calls HTTP POST" do
      req = stub_request(:post, "https://a.b").
        with(body: "{}", headers: {"Content-Type" => "application/json"}).
        to_return(status: 200, body: "")
      qreq = stub_request(:post, "https://x.y").
        with(body: {x: 1}.to_json).
        to_return(status: 200, body: "")
      described_class.post("https://a.b", logger: nil, timeout: nil)
      described_class.post("https://x.y", {x: 1}, logger: nil, timeout: nil)
      expect(req).to have_been_made
      expect(qreq).to have_been_made
    end

    it "does not to_json string body" do
      req = stub_request(:post, "https://a.b").
        with(body: "xyz").
        to_return(status: 200, body: "")
      described_class.post("https://a.b", "xyz", logger: nil, timeout: nil)
      expect(req).to have_been_made
    end

    it "does not to_json if content type is not json" do
      req = stub_request(:post, "https://a.b").
        with(body: "x=1").
        to_return(status: 200, body: "")
      described_class.post(
        "https://a.b",
        {x: 1},
        headers: {"Content-Type" => "xyz"}, logger: nil, timeout: nil,
      )
      expect(req).to have_been_made
    end

    it "requires a :timeout" do
      expect { described_class.post("https://x.y") }.to raise_error(ArgumentError, "must pass :timeout keyword")
    end

    it "requires a :logger" do
      expect do
        described_class.post("https://x.y", timeout: nil)
      end.to raise_error(ArgumentError, "must pass :logger keyword")
    end

    it "passes through options and merges headers" do
      req = stub_request(:post, "https://a.b/").
        with(
          headers: {
            "Abc" => "123",
            "Content-Type" => "x/y",
            "User-Agent" => "WebhookDB/unknown-release https://webhookdb.com 1970-01-01T00:00:00Z",
          },
        ).
        to_return(status: 200, body: "", headers: {})
      described_class.post(
        "https://a.b",
        logger: nil, timeout: nil,
        headers: {"ABC" => "123", "Content-Type" => "x/y"},
        basic_auth: {username: "u", password: "p"},
      )
      expect(req).to have_been_made
    end

    it "errors on non-ok" do
      stub_request(:post, "https://a.b/").
        to_return(status: 500, body: "meh")

      expect { described_class.post("https://a.b", logger: nil, timeout: nil) }.to raise_error(described_class::Error)
    end

    it "does not error if check is false" do
      stub_request(:post, "https://a.b/").
        to_return(status: 500, body: "meh")

      resp = described_class.post("https://a.b", check: false, logger: nil, timeout: nil)
      expect(resp).to have_attributes(code: 500)
    end

    it "does not error for 300s if not following redirects" do
      req = stub_request(:post, "https://a.b").to_return(status: 307, headers: {location: "https://x.y"})
      resp = described_class.post("https://a.b", logger: nil, timeout: nil, follow_redirects: false)
      expect(req).to have_been_made
      expect(resp).to have_attributes(code: 307)
    end

    it "passes through a block" do
      req = stub_request(:post, "https://a.b").to_return(status: 200, body: "abc")
      t = +""
      described_class.post("https://a.b", logger: nil, timeout: nil) do |f|
        t << f
      end
      expect(req).to have_been_made
      expect(t).to eq("abc")
    end
  end

  describe "chunked_download" do
    it "opens a stream" do
      req = stub_request(:get, "https://a.b").
        with(headers: {
               "Accept" => "*/*",
               "Accept-Encoding" => "gzip, deflate",
               "User-Agent" => %r{WebhookDB/},
             }).
        to_return(status: 200, body: "abc")
      io = described_class.chunked_download("https://a.b", rewindable: false)
      expect(req).to have_been_made
      expect(io).to be_a(Down::ChunkedIO)
      expect(io.read).to eq("abc")
    end

    it "raises without an http url" do
      expect do
        described_class.chunked_download("webcal://a.b")
      end.to raise_error(URI::InvalidURIError, "webcal://a.b must be an http/s url")

      expect do
        described_class.chunked_download("httpss://a.b")
      end.to raise_error(URI::InvalidURIError, "httpss://a.b must be an http/s url")
    end

    it "patches httpx to handle bad encodings" do
      req = stub_request(:get, "https://a.b").
        to_return(status: 200, body: "abc", headers: {"Content-Type" => "text/html;charset=utf8"})
      io = described_class.chunked_download("https://a.b", rewindable: false)
      expect(req).to have_been_made
      expect(io.read).to eq("abc")
    end
  end

  describe "Error" do
    it "is rendered nicely" do
      stub_request(:get, "https://a.b/").
        to_return(status: 500, body: "meh", headers: {"X" => "y"})
      begin
        described_class.get("https://a.b", logger: nil, timeout: nil)
      rescue Webhookdb::Http::Error => e
        nil
      end
      expect(e).to_not be_nil
      expect(e.to_s).to eq("HttpError(status: 500, method: GET, uri: https://a.b/?, body: meh)")
    end

    it "sanitizes query params with secret or access" do
      stub_request(:get, "https://api.convertkit.com/v3/subscribers?api_secret=bfsek&page=1").
        to_return(status: 500, body: "meh")
      begin
        described_class.get("https://api.convertkit.com/v3/subscribers?api_secret=bfsek&page=1", logger: nil,
                                                                                                 timeout: nil,)
      rescue Webhookdb::Http::Error => e
        nil
      end
      expect(e).to_not be_nil
      expect(e.to_s).to eq(
        "HttpError(status: 500, method: GET, " \
        "uri: https://api.convertkit.com/v3/subscribers?api_secret=.snip.&page=1, body: meh)",
      )
    end
  end

  describe "user_agent" do
    after(:each) do
      Webhookdb.reset_configuration
    end

    it "uses algorithm to calculate user agent if one isn't provided" do
      Webhookdb.http_user_agent = ""
      expect(described_class.user_agent).to eq("WebhookDB/unknown-release https://webhookdb.com 1970-01-01T00:00:00Z")
    end

    it "uses custom user agent if one is provided" do
      Webhookdb.http_user_agent = "User Agent"
      expect(described_class.user_agent).to eq("User Agent")
    end
  end

  describe "logging" do
    it "logs structured request information" do
      logger = SemanticLogger["http_spec_logging_test"]
      stub_request(:post, "https://foo/bar").to_return(json_response({o: "k"}))
      logs = capture_logs_from(logger, formatter: :json) do
        described_class.post("https://foo/bar", {x: 1}, logger:, timeout: nil)
      end
      expect(logs.map { |j| JSON.parse(j) }).to contain_exactly(
        include("message" => "httparty_request", "context" => include("http_method" => "POST"), "level" => "debug"),
      )
    end
  end

  it "patches down https to handle more status codes correctly" do
    req = stub_request(:get, "https://a.b").to_return(status: 304)
    expect do
      Down::Httpx.download("https://a.b")
    end.to raise_error(Down::NotModified)
    expect(req).to have_been_made.times(1)

    # Make sure original errors work
    req = stub_request(:get, "https://a.b").to_return(status: 400)
    expect do
      Down::Httpx.download("https://a.b")
    end.to raise_error(Down::ClientError)
    expect(req).to have_been_made.times(2)
  end
end
