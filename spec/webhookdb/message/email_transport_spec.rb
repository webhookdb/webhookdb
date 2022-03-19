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

  describe "send!" do
    it "sends mail to Postmark" do
      send_mail_req = stub_email_post(
        with: {body: hash_including("From" => /WebhookDB/, "To" => "blah@lithic.tech")},
        message_id: "abcdefg",
      )

      delivery = Webhookdb::Fixtures.message_delivery.email("blah@lithic.tech").create
      result = described_class.new.send!(delivery)
      expect(result).to eq("abcdefg")

      expect(send_mail_req).to have_been_made
    end

    it "uses the default recipient email and password" do
      send_mail_req = stub_email_post(
        with: {body: hash_including("To" => "Hugh Bode <hi@lithic.tech>")},
        message_id: "abcdefg",
      )

      customer = Webhookdb::Fixtures.customer(name: "Hugh Bode", email: "hi@lithic.tech").create

      delivery = Webhookdb::Fixtures.message_delivery.email.to(customer).create
      described_class.new.send!(delivery)

      expect(send_mail_req).to have_been_made
    end

    it "errors if Postmark succeeds but returns an error code" do
      send_mail_req = stub_email_post(status: 200, fixture: "postmark/mail_send_error")

      delivery = Webhookdb::Fixtures.message_delivery.email("blah@lithic.tech").create

      expect do
        described_class.new.send!(delivery)
      end.to raise_error(Webhookdb::Message::Transport::Error)

      expect(send_mail_req).to have_been_made
    end

    it "raises UndeliverableRecipient error if it is a Postmark::InactiveRecipientError" do
      send_mail_req = stub_email_post(status: 422, fixture: "postmark/mail_send_inactive_recipient")

      delivery = Webhookdb::Fixtures.message_delivery.email("blah@lithic.tech").create

      expect do
        described_class.new.send!(delivery)
      end.to raise_error(Webhookdb::Message::Transport::UndeliverableRecipient, /cannot be reached/)

      expect(send_mail_req).to have_been_made
    end

    it "raises UndeliverableRecipient error if it is a Postmark::InvalidEmailAddressError" do
      send_mail_req = stub_email_post(status: 422, fixture: "postmark/mail_send_invalid_email")
      delivery = Webhookdb::Fixtures.message_delivery.email("blah@lithic.tech").create

      expect do
        described_class.new.send!(delivery)
      end.to raise_error(Webhookdb::Message::Transport::UndeliverableRecipient, /Error parsing/)

      expect(send_mail_req).to have_been_made
    end

    it "raises error if the email is not allowlisted" do
      delivery = Webhookdb::Fixtures.message_delivery.email("stone@gmail.com").create
      expect do
        described_class.new.send!(delivery)
      end.to raise_error(Webhookdb::Message::Transport::UndeliverableRecipient,
                         /is not allowlisted/,)
    end

    it 'pulls "reply_to" and "from" from extra fields' do
      send_mail_req = stub_email_post(
        with: {
          body: hash_including(
            "From" => "us@us.com",
            "ReplyTo" => "customer@foo.com",
          ),
        },
      )

      delivery = Webhookdb::Fixtures.message_delivery.
        email("chef@lithic.tech").
        extra("reply_to", "customer@foo.com").
        extra("from", "us@us.com").
        create
      result = described_class.new.send!(delivery)
      expect(result).to be_a(String)

      expect(send_mail_req).to have_been_made
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
