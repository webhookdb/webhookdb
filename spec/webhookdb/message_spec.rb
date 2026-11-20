# frozen_string_literal: true

require "webhookdb/message"
require "webhookdb/messages/specs"

RSpec.describe "Webhookdb::Message", :db, :messaging do
  let(:described_class) { Webhookdb::Message }
  let(:testers) { Webhookdb::Messages::Testers }

  describe "dispatch" do
    let(:basic) { Webhookdb::Messages::Testers::Basic.new }

    it "creates an undelivered message to the given recipient", messaging: false do
      recipient = Webhookdb::Fixtures.customer.create
      delivery = basic.dispatch(recipient)

      expect(delivery).to have_attributes(
        template: "specs/basic",
        transport_type: "email",
        transport_service: "smtp",
        transport_message_id: nil,
        sent_at: nil,
        to: recipient.email,
        recipient:,
      )
      expect(delivery.bodies).to have_length(be >= 1)
    end

    it "can send a message to a bare email" do
      delivery = basic.dispatch("customer@lithic.tech")
      expect(delivery).to have_attributes(
        to: "customer@lithic.tech",
        recipient: nil,
      )
    end

    it "can specify a different transport" do
      delivery = basic.dispatch("customer@lithic.tech", transport: :fake)
      expect(delivery).to have_attributes(
        transport_type: "fake",
        transport_service: "fake",
      )
    end

    it "errors if the transport is invalid", messaging: false do
      expect do
        basic.dispatch("customer@lithic.tech", transport: :fake2)
      end.to raise_error(Webhookdb::Message::InvalidTransportError)
    end

    it "renders bodies using the specified transport" do
      delivery = basic.dispatch("customer@lithic.tech", transport: :fake)
      expect(delivery.bodies).to have_length(1)
      expect(delivery.bodies.first).to have_attributes(content: match("test message to customer@lithic.tech"))
    end
  end

  describe "rendering" do
    let(:recipient) { Webhookdb::Message::Recipient.new("customer@lithic.tech", nil) }

    it "errors if a template for the specified transport does not exist" do
      expect do
        tmpl = testers::Nonextant.new
        Webhookdb::Message.render(tmpl, :fake, recipient)
      end.to raise_error(Webhookdb::Message::MissingTemplateError)
    end

    it "renders the template using the given attributes" do
      tmpl = testers::WithField.new(2)
      r = Webhookdb::Message.render(tmpl, :fake, recipient)
      expect(r.contents.strip).to eq("test message to customer@lithic.tech, field 2")
    end

    it "renders strictly" do
      expect do
        tmpl = testers::MissingField.new
        Webhookdb::Message.render(tmpl, :fake, recipient)
      end.to raise_error(Liquid::UndefinedVariable)
    end

    it "exposes variables from the template" do
      tmpl = testers::WithField.new(2)
      r = Webhookdb::Message.render(tmpl, :email, recipient)
      expect(r[:subject]).to eq("subject with field 2 to customer@lithic.tech")
    end

    it "can use includes" do
      tmpl = testers::WithInclude.new
      r = Webhookdb::Message.render(tmpl, :email, recipient)
      expect(r.contents.strip).to eq("field before is 3. including: partial has field of 3")
    end

    it "can use partial" do
      tmpl = testers::WithPartial.new
      r = Webhookdb::Message.render(tmpl, :email, recipient)
      expect(r.contents).to include("<p>&mdash; The team at WebhookDB")
    end

    it "can use layout" do
      tmpl = testers::WithLayout.new
      r = Webhookdb::Message.render(tmpl, :email, recipient)
      expect(r.contents.strip).to start_with("<!DOCTYPE html")
      expect(r.contents).to include("email to")
      expect(r.contents.strip).to end_with("</html>")
    end

    it "encodes non-UTF-8 string liquid drops into UTF-8 to avoid an exception" do
      ascii8bit_str = [255].pack("c*")
      expect(ascii8bit_str.encoding).to eq(Encoding.find("ASCII-8BIT"))
      utf8_str = "\u0777"
      expect(utf8_str.encoding).to eq(Encoding.find("UTF-8"))
      tmpl = testers::WithFields.new(a: ascii8bit_str, b: utf8_str, c: 4, d: "w".encode("ASCII"))
      r = Webhookdb::Message.render(tmpl, :email, recipient)
      expect(r.contents.strip).to eq("a: ?\nb: ݷ\nc: 4\nd: w\ne:")
    end
  end

  describe "send_unsent" do
    it "sends unsent deliveries" do
      unsent = Webhookdb::Fixtures.message_delivery.create
      sent = Webhookdb::Fixtures.message_delivery.sent.create

      expect do
        Webhookdb::Message.send_unsent
      end.to not_change { sent.refresh.sent_at }.and(
        change { unsent.refresh.sent_at }.from(nil),
      )
    end
  end

  it "can fixture all message templates" do
    recipient = Webhookdb::Fixtures.customer.create
    Webhookdb::Message::Template.subclasses.each do |cls|
      expect { cls.fixtured(recipient) }.to_not raise_error
    end
  end
end
