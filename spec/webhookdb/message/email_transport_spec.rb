# frozen_string_literal: true

require "webhookdb/message"

RSpec.describe Webhookdb::Message::EmailTransport, :db do
  describe "add_bodies" do
    it "renders subject, plain text, and HTML/inlined CSS bodies" do
      delivery = Webhookdb::Fixtures.message_delivery.via(:email).create
      described_class.new.add_bodies(delivery, Webhookdb::Message::Rendering.new("<p>hi</p>", subject: "Hello"))

      expect(delivery.bodies).to contain_exactly(
        have_attributes(content: "Hello", mediatype: "subject"),
        have_attributes(content: "hi", mediatype: "text/plain"),
        have_attributes(content: include("<html><body><p>hi</p>"), mediatype: "text/html"),
      )
    end

    it "errors if content is not a string or has no subject" do
      delivery = Webhookdb::Fixtures.message_delivery.via(:email).create
      xport = described_class.new
      expect do
        xport.add_bodies(delivery, "hello")
      end.to raise_error(/missing a subject/)

      expect do
        xport.add_bodies(delivery, Webhookdb::Message::Rendering.new("<p>hi</p>"))
      end.to raise_error(/missing a subject/)
    end
  end

  describe "send!", reset_configuration: described_class do
    it "sends mail via SMTP" do
      delivery = Webhookdb::Fixtures.message_delivery.email("blah@lithic.tech").create
      result = described_class.new.send!(delivery)
      expect(result).to have_length(36)

      expect(fetch_last_email).to include(
        "From" => {"Address" => "hello@webhookdb.com", "Name" => "WebhookDB"},
        "To" => [{"Address" => "blah@lithic.tech", "Name" => ""}],
      )
    end

    it "uses the recipient email and name" do
      customer = Webhookdb::Fixtures.customer(name: "Hugh Bode", email: "hi@lithic.tech").create
      delivery = Webhookdb::Fixtures.message_delivery.email.to(customer).create
      described_class.new.send!(delivery)
      expect(fetch_last_email).to include(
        "To" => [{"Address" => "hi@lithic.tech", "Name" => "Hugh Bode"}],
      )
    end

    it "raises error if the email is not allowlisted" do
      delivery = Webhookdb::Fixtures.message_delivery.email("stone@gmail.com").create
      expect do
        described_class.new.send!(delivery)
      end.to raise_error(Webhookdb::Message::Transport::UndeliverableRecipient, /is not allowlisted/)
    end

    it 'pulls "reply_to" and "from" from extra fields' do
      delivery = Webhookdb::Fixtures.message_delivery.
        email("chef@lithic.tech").
        extra("reply_to", "customer@foo.com").
        extra("from", "us@us.com").
        create
      result = described_class.new.send!(delivery)
      expect(result).to be_a(String)

      expect(fetch_last_email).to include(
        "From" => {"Address" => "us@us.com", "Name" => ""},
        "Headers" => include("Reply-To" => ["customer@foo.com"]),
      )
    end

    it "sets particular headers for postmark smtp provider" do
      described_class.smtp_provider = "postmark"
      delivery = Webhookdb::Fixtures.message_delivery.email("blah@lithic.tech").create
      result = described_class.new.send!(delivery)
      expect(result).to have_length(36)

      expect(fetch_last_email).to include(
        "Headers" => include(
          "X-Pm-Metadata-Messageid" => [result], "X-Pm-Tag" => ["fixture"],
        ),
      )
    end

    it "includes smtp_headers config" do
      described_class.smtp_headers = {"X-MyHeader" => "abc", "X-Array" => ["x", "y"]}
      delivery = Webhookdb::Fixtures.message_delivery.email("blah@lithic.tech").create
      described_class.new.send!(delivery)

      expect(fetch_last_email).to include(
        "Headers" => include("X-Array" => ["x, y"], "X-Myheader" => ["abc"]),
      )
    end
  end

  describe "recipient" do
    it "uses the customers default email for :to" do
      u = Webhookdb::Fixtures.customer.create
      expect(described_class.new.recipient(u)).to have_attributes(to: u.email, customer: u)
    end

    it "uses the value for :to if not a customer" do
      expect(described_class.new.recipient("f@b.c")).to have_attributes(to: "f@b.c", customer: nil)
    end
  end
end
