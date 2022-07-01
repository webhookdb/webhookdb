# frozen_string_literal: true

require "webhookdb/message"
require "webhookdb/twilio"

RSpec.describe Webhookdb::Message::SmsTransport, :db do
  describe "send!" do
    it "sends message via Twilio" do
      req = stub_twilio_sms(sid: "SMXYZ").
        with(
          body: {"Body" => "hello", "From" => "17742606953", "To" => "+15554443210"},
          headers: {"Authorization" => "Basic QUM0NDR0ZXN0OmFjNDV0ZXN0"},
        )
      delivery = Webhookdb::Fixtures.message_delivery.sms("+15554443210", content: "hello").create
      result = described_class.new.send!(delivery)
      expect(result).to eq("SMXYZ")
      expect(req).to have_been_made
    end

    it "formats the provided phone number" do
      req = stub_twilio_sms.
        with(body: {"Body" => "hello", "From" => "17742606953", "To" => "+15554443210"})
      delivery = Webhookdb::Fixtures.message_delivery.sms("(555) 444-3210", content: "hello").create
      described_class.new.send!(delivery)
      expect(req).to have_been_made
    end

    it "raises error if formatted phone is nil" do
      delivery = Webhookdb::Fixtures.message_delivery.sms("invalid").create
      expect do
        described_class.new.send!(delivery)
      end.to raise_error(/could not format/i)
    end

    it "raises error if the phone number is not allowlisted" do
      delivery = Webhookdb::Fixtures.message_delivery.sms("404-555-0128").create
      expect do
        described_class.new.send!(delivery)
      end.to raise_error(Webhookdb::Message::Transport::UndeliverableRecipient,
                         /the number is not allowlisted/,)
    end

    it "warns and noops if the phone number is invalid" do
      req = stub_twilio_sms(fixture: "twilio/send_message_invalid_number", status: 400)
      lines = capture_logs_from(Webhookdb::Twilio.logger) do
        delivery = Webhookdb::Fixtures.message_delivery.sms("(555) 444-3210", content: "hello").create
        described_class.new.send!(delivery)
      end
      expect(req).to have_been_made
      expect(lines).to have_a_line_matching(/twilio_invalid_phone_number/)
    end
  end

  describe "format_phone" do
    it "returns a phone number in E.164 format with a US country code" do
      expect(described_class.format_phone("5554443210")).to eq("+15554443210")
    end

    it "strips non-numeric characters if present" do
      expect(described_class.format_phone("(555) 444-3210")).to eq("+15554443210")
    end

    it "handles a country code already being present" do
      expect(described_class.format_phone("+1 (555) 444-3210")).to eq("+15554443210")
    end

    it "does not modify a properly formatted US number" do
      expect(described_class.format_phone("+15554443210")).to eq("+15554443210")
    end

    it "returns nil if number is not valid" do
      expect(described_class.format_phone("555444321")).to be_nil
      expect(described_class.format_phone("notaphonenumber")).to be_nil
      expect(described_class.format_phone("")).to be_nil
      expect(described_class.format_phone(nil)).to be_nil
    end
  end

  describe "add_bodies" do
    it "renders plain text" do
      delivery = Webhookdb::Fixtures.message_delivery.via(:sms).create
      described_class.new.add_bodies(delivery, Webhookdb::Message::Rendering.new("hello"))
      expect(delivery.bodies).to contain_exactly(have_attributes(content: "hello", mediatype: "text/plain"))
    end

    it "errors if content is not set" do
      delivery = Webhookdb::Fixtures.message_delivery.via(:sms).create
      xport = described_class.new
      expect do
        xport.add_bodies(delivery, "")
      end.to raise_error(/content is not set/i)
    end
  end
end
