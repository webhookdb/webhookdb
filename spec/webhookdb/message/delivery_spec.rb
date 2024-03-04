# frozen_string_literal: true

RSpec.describe "Webhookdb::Message::Delivery", :db, :messaging do
  let(:described_class) { Webhookdb::Message::Delivery }

  before(:each) do
    Webhookdb::Message::FakeTransport.reset!
  end

  it "can fixture and full text search" do
    expect { Webhookdb::Fixtures.message_delivery.create.text_search_reindex }.to_not raise_error
    expect { Webhookdb::Fixtures.message_delivery.email.create }.to_not raise_error
    expect { Webhookdb::Fixtures.message_delivery.to("x").create }.to_not raise_error
    expect { Webhookdb::Fixtures.message_delivery.with_recipient.create }.to_not raise_error
    expect { Webhookdb::Fixtures.message_delivery.with_body.create }.to_not raise_error
    expect { Webhookdb::Fixtures.message_delivery.via(:email).create }.to_not raise_error
    expect { Webhookdb::Fixtures.message_delivery.sent.create }.to_not raise_error
  end

  context "datasets" do
    it "has a dataset for sent and unsent messages" do
      unsent = Webhookdb::Fixtures.message_delivery.create
      sent = Webhookdb::Fixtures.message_delivery.sent.create
      deleted = Webhookdb::Fixtures.message_delivery.create.soft_delete

      expect(described_class.unsent.all).to contain_exactly(unsent)
      expect(described_class.sent.all).to contain_exactly(sent)
    end

    it "has a dataset to messages to a customer dataset or array, where they are the recipient or to address" do
      customer = Webhookdb::Fixtures.customer.create
      to_customer = Webhookdb::Fixtures.message_delivery.with_recipient(customer).create
      to_email = Webhookdb::Fixtures.message_delivery.to(customer.email).create
      Webhookdb::Fixtures.message_delivery.with_recipient.create
      Webhookdb::Fixtures.message_delivery.create

      expect(described_class.to_customers([customer]).all).to contain_exactly(to_email, to_customer)
      expect(described_class.to_customers(Webhookdb::Customer.where(id: customer.id)).all).to contain_exactly(
        to_email, to_customer,
      )
    end
  end

  describe "body_with_mediatype" do
    it "returns the first body with a given mediatype" do
      d = Webhookdb::Fixtures.message_delivery.create
      subj = d.add_body(mediatype: "subject", content: "Subject")
      text = d.add_body(mediatype: "text", content: "plaintext")
      html = d.add_body(mediatype: "html", content: "<html>")
      expect(d.body_with_mediatype("text")).to be === text
      expect(d.body_with_mediatype("abc")).to be_nil
    end
  end

  describe "body_with_mediatype!" do
    it "raises if no body matches the given" do
      expect do
        Webhookdb::Fixtures.message_delivery.create.body_with_mediatype!("abc")
      end.to raise_error(/has no body with mediatype/)
    end
  end

  describe "send" do
    it "does not deliver sent messages" do
      d = Webhookdb::Fixtures.message_delivery.sent.create
      expect(d.send!).to be_nil
      expect(Webhookdb::Message::FakeTransport.sent_deliveries).to be_empty
    end

    it "does not deliver deleted messages" do
      d = Webhookdb::Fixtures.message_delivery.sent.create
      d.soft_delete
      expect(d.send!).to be_nil
      expect(Webhookdb::Message::FakeTransport.sent_deliveries).to be_empty
    end

    it "sends messages through the configured transport" do
      d = Webhookdb::Fixtures.message_delivery.create
      expect(d.send!).to_not be_nil
      expect(Webhookdb::Message::FakeTransport.sent_deliveries).to contain_exactly(d)
    end

    it "updates fields about the sending" do
      d = Webhookdb::Fixtures.message_delivery.create
      d.send!
      expect(d).to have_attributes(
        sent_at: be_within(5).of(Time.now),
        transport_message_id: start_with("#{d.id}-"),
      )
    end

    it "soft deletes delivery if UndeliverableRecipient error is raised" do
      d = Webhookdb::Fixtures.message_delivery.create
      Webhookdb::Message::FakeTransport.disable_func = proc { true }
      expect(d.send!).to_not be_nil
      expect(d.soft_deleted_at).to be_within(5).of(Time.now)
    end

    it "sets transport message ID as warning if the transport message ID is nil" do
      d = Webhookdb::Fixtures.message_delivery.create
      Webhookdb::Message::FakeTransport.return_nil_on_send = true

      expect(d.send!).to_not be_nil
      expect(d.transport_message_id).to eq("WARNING-NOT-SET")
    end
  end

  describe "fixtures" do
    let(:customer) { Webhookdb::Fixtures.customer.create }

    it "can specify a recipient" do
      d = Webhookdb::Fixtures.message_delivery.to("me@co.co").create
      expect(d).to have_attributes(transport_type: "fake", to: "me@co.co", recipient: nil)

      d = Webhookdb::Fixtures.message_delivery.to(customer).create
      expect(d).to have_attributes(transport_type: "fake", to: customer.email, recipient: customer)
    end

    it "can specify a transport" do
      d = Webhookdb::Fixtures.message_delivery.via(:email).create
      expect(d).to have_attributes(transport_type: "email", to: "fixture-to")

      d = Webhookdb::Fixtures.message_delivery(recipient: customer).via(:email).create
      expect(d).to have_attributes(transport_type: "email", to: customer.email, recipient: customer)
    end

    it "can fixture an email with bodies" do
      d = Webhookdb::Fixtures.message_delivery.email.create
      expect(d).to have_attributes(transport_type: "email", to: include("@"), recipient: nil)
      expect(d.bodies).to contain_exactly(
        have_attributes(mediatype: "subject"),
        have_attributes(mediatype: "text/plain"),
        have_attributes(mediatype: "text/html"),
      )

      d = Webhookdb::Fixtures.message_delivery.to(customer).email.create
      expect(d).to have_attributes(transport_type: "email", to: customer.email, recipient: customer)
    end

    it "can be marked sent" do
      expect(Webhookdb::Fixtures.message_delivery.sent.create).to have_attributes(sent_at: be_within(5).of(Time.now))
    end
  end

  describe "preview" do
    it "errors if rack env is not development and commit is true" do
      expect do
        described_class.preview("NewCustomer", rack_env: "test", commit: true)
      end.to raise_error(/only preview in development/)

      expect do
        described_class.preview("NewCustomer", rack_env: "test", commit: false)
      end.to_not raise_error
    end

    it "errors if the template does not exist" do
      expect do
        described_class.preview("NotExisting", rack_env: "development")
      end.to raise_error(Webhookdb::Message::MissingTemplateError)
    end

    it "returns the delivery but rolls back changes" do
      customer_count = Webhookdb::Customer.count

      delivery = described_class.preview("NewCustomer", rack_env: "development")

      expect(delivery).to be_a(described_class)
      expect(Webhookdb::Customer.count).to eq(customer_count)
      expect(Webhookdb::Message::Delivery[id: delivery.id]).to be_nil
    end

    it "can commit changes" do
      customer_count = Webhookdb::Customer.count

      delivery = described_class.preview("NewCustomer", commit: true, rack_env: "development")

      expect(delivery).to be_a(described_class)
      expect(Webhookdb::Customer.count).to eq(customer_count + 1)
      expect(Webhookdb::Message::Delivery[id: delivery.id]).to be === delivery
    end
  end
end
