# frozen_string_literal: true

require "webhookdb/front"

RSpec.describe Webhookdb::Front do
  let(:body) { '{"data": "asdfghujkl"}' }
  let(:front_timestamp_header) { Time.new(2023, 4, 7).to_i.to_s }

  def valid_req
    base_string = "#{front_timestamp_header}:#{body}"
    valid_auth_header = OpenSSL::HMAC.base64digest(OpenSSL::Digest.new("sha256"), Webhookdb::Front.api_secret,
                                                   base_string,)
    req = fake_request(input: body)
    req.add_header("HTTP_X_FRONT_REQUEST_TIMESTAMP", front_timestamp_header)
    req.add_header("HTTP_X_FRONT_SIGNATURE", valid_auth_header)
    return req
  end

  def invalid_req
    req = fake_request(input: body)
    req.add_header("HTTP_X_FRONT_REQUEST_TIMESTAMP", front_timestamp_header)
    req.add_header("HTTP_X_FRONT_SIGNATURE", "open_sesame")
    return req
  end

  describe "verify_signature" do
    it "returns false for invalid auth headers" do
      expect(described_class.verify_signature(invalid_req)).to be(false)
    end

    it "returns true for valid auth headers" do
      expect(described_class.verify_signature(valid_req)).to be(true)
    end
  end

  describe "webhook_response" do
    it "returns a 401 if there is no signature header" do
      req = fake_request(input: body)
      resp = described_class.webhook_response(req)
      expect(resp).to have_attributes(status: 401, reason: "missing signature")
    end

    it "returns a 401 for an invalid signature header" do
      resp = described_class.webhook_response(invalid_req)
      expect(resp).to have_attributes(status: 401, reason: "invalid signature")
    end

    it "returns a 200 with a valid signature header" do
      resp = described_class.webhook_response(valid_req)
      expect(resp).to have_attributes(status: 200)
    end
  end

  describe "initial_verification_request_response" do
    it "returns error when credentials are invalid" do
      resp = described_class.initial_verification_request_response(invalid_req)
      expect(resp).to have_attributes(status: 401, reason: "invalid credentials")
    end

    it "returns challenge string when credentials are valid" do
      req = valid_req
      req.add_header("HTTP_X_FRONT_CHALLENGE", "challenge_string")

      resp = described_class.initial_verification_request_response(req)
      expect(resp).to have_attributes(
        status: 200,
        body: {challenge: "challenge_string"}.to_json,
      )
    end
  end
end
