# frozen_string_literal: true

require "webhookdb/increase"

RSpec.describe "Webhookdb::Increase" do
  let(:described_class) { Webhookdb::Increase }

  describe "webhook validation" do
    let(:req) { fake_request(input: '{"data": "asdfghujkl"}') }
    let(:data) { req.body }
    let(:secret) { "webhook_secret" }

    describe "parse_signature" do
      it "parses all variety of signatures" do
        t = Time.parse("2022-01-31T23:59:59Z")
        expect(described_class.parse_signature(nil)).to have_attributes(t: nil, v1: [])
        expect(described_class.parse_signature("")).to have_attributes(t: nil, v1: [])
        expect(described_class.parse_signature("t=2022-01-31T23:59:59Z")).to have_attributes(t:, v1: [])
        expect(described_class.parse_signature("t=abcd")).to have_attributes(t: nil, v1: [])
        expect(described_class.parse_signature("t=abcd,v1=abcd")).to have_attributes(t: nil, v1: ["abcd"])
        expect(described_class.parse_signature("t=abcd,v1=abcd,v2=xyz")).to have_attributes(t: nil, v1: ["abcd"])
        expect(described_class.parse_signature("t=2022-01-31T23:59:59Z,v1=ab,v1=cd")).to have_attributes(
          t:, v1: ["ab", "cd"],
        )
      end
    end

    describe "Signature" do
      describe "format" do
        it "formats" do
          t = Time.parse("2022-01-31T23:59:59Z")
          sig = described_class::WebhookSignature.new(t:, v1: ["ab", "cd"])
          expect(sig.format).to eq("t=2022-01-31T23:59:59Z,v1=ab,v1=cd")
          sig.v1 = ["ab"]
          expect(sig.format).to eq("t=2022-01-31T23:59:59Z,v1=ab")
          sig.t = nil
          expect(sig.format).to eq("v1=ab")
          sig.v1 = ["ab"]
          expect(sig.format).to eq("v1=ab")
          sig.v1 = []
          expect(sig.format).to eq("")
        end
      end
    end

    describe "webhook_response" do
      it "returns a 401 as per spec if there is no Authorization header" do
        resp = Webhookdb::Increase.webhook_response(req, "webhook_secret")
        expect(resp).to have_attributes(status: 401, reason: "missing header")
      end

      it "returns a 401 for an invalid Authorization header (no timestamp)" do
        sig = described_class.compute_signature(secret:, data:, t: Time.now)
        sig.t = nil
        req.add_header("HTTP_INCREASE_WEBHOOK_SIGNATURE", sig.format)
        resp = Webhookdb::Increase.webhook_response(req, secret)
        expect(resp).to have_attributes(status: 401, reason: "missing timestamp")
      end

      it "returns a 401 for an invalid Authorization header (no v1)" do
        sig = described_class.compute_signature(secret:, data:, t: Time.now)
        sig.v1 = nil
        req.add_header("HTTP_INCREASE_WEBHOOK_SIGNATURE", sig.format)
        resp = Webhookdb::Increase.webhook_response(req, secret)
        expect(resp).to have_attributes(status: 401, reason: "missing signatures")
      end

      it "returns a 401 for an invalid Authorization header (invalid v1)" do
        sig = described_class.compute_signature(secret:, data:, t: Time.now)
        sig.v1[0] = "notvalid hash"
        req.add_header("HTTP_INCREASE_WEBHOOK_SIGNATURE", sig.format)
        resp = Webhookdb::Increase.webhook_response(req, secret)
        expect(resp).to have_attributes(status: 401, reason: "invalid signature")
      end

      it "returns a 401 for an invalid Authorization header (timestamp old)" do
        sig = described_class.compute_signature(secret:, data:, t: Time.now)
        sig.t = 40.days.ago
        req.add_header("HTTP_INCREASE_WEBHOOK_SIGNATURE", sig.format)
        resp = Webhookdb::Increase.webhook_response(req, secret)
        expect(resp).to have_attributes(status: 401, reason: "too old")
      end

      it "returns a 401 for an invalid Authorization header (timestamp future)" do
        sig = described_class.compute_signature(secret:, data:, t: Time.now)
        sig.t = 1.week.from_now
        req.add_header("HTTP_INCREASE_WEBHOOK_SIGNATURE", sig.format)
        resp = Webhookdb::Increase.webhook_response(req, secret)
        expect(resp).to have_attributes(status: 401, reason: "too new")
      end

      it "returns a 202 if the signature and timestamp matches (single signature)" do
        sig = described_class.compute_signature(secret:, data:, t: Time.now)
        req.add_header("HTTP_INCREASE_WEBHOOK_SIGNATURE", sig.format)
        resp = Webhookdb::Increase.webhook_response(req, secret)
        expect(resp).to have_attributes(status: 202)
      end

      it "returns a 202 if the signature and timestamp matches (multiple signatures)" do
        sig = described_class.compute_signature(secret:, data:, t: Time.now)
        sig.v1 = ["invalid1", sig.v1.first, "invalid2"]
        req.add_header("HTTP_INCREASE_WEBHOOK_SIGNATURE", sig.format)
        resp = Webhookdb::Increase.webhook_response(req, secret)
        expect(resp).to have_attributes(status: 202)
      end
    end
  end
end
