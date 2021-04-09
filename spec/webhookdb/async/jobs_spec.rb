# frozen_string_literal: true

require "webhookdb/async"
require "webhookdb/jobs/backfill"
require "webhookdb/messages/specs"
require "rspec/eventually"

RSpec.describe "webhookdb async jobs", :async, :db, :do_not_defer_events, :no_transaction_check do
  before(:all) do
    Webhookdb::Async.require_jobs
  end

  describe "Backfill" do
    let(:page1_items) do
      [
        {"my_id" => "1", "at" => "Thu, 30 Jul 2015 21:12:33 +0000"},
        {"my_id" => "2", "at" => "Thu, 30 Jul 2015 21:12:33 +0000"},
      ]
    end
    it "starts backfill process" do
      sint = Webhookdb::Fixtures.service_integration.create(
        backfill_key: "bfkey",
        backfill_secret: "bfsek",
      )
      Webhookdb::Services::Fake.backfill_responses = {
        nil => [page1_items, nil],
      }
      Webhookdb::Services.service_instance(sint).create_table
      # Webhookdb::Jobs::Backfill.new._perform(Webhookdb::Event.new('x', 'y', [sint.id]))
      expect do
        Webhookdb.publish(
          "webhookdb.service.backfill", sint.id,
        )
      end.to perform_async_job(Webhookdb::Jobs::Backfill)
      expect(Webhookdb::Services.service_instance(sint).dataset.all).to have_length(2)
    end
  end

  describe "CreateMirrorTable" do
    it "creates the table for the service integration" do
      sint = nil
      expect do
        sint = Webhookdb::Fixtures.service_integration.create
      end.to perform_async_job(Webhookdb::Async::CreateMirrorTable)

      expect(sint).to_not be_nil
      expect(Webhookdb::Customer.db.table_exists?(sint&.table_name)).to be_truthy
    end
  end

  describe "MessageDispatched", messaging: true do
    it "sends the delivery on create" do
      email = "wibble@lithic.tech"

      expect do
        Webhookdb::Messages::Testers::Basic.new.dispatch(email)
      end.to perform_async_job(Webhookdb::Async::MessageDispatched)

      expect(Webhookdb::Message::Delivery).to have_row(to: email).
        with_attributes(transport_message_id: be_a(String))
    end
  end

  describe "ProcessWebhook" do
    it "passes the payload off to the processor" do
      sint = Webhookdb::Fixtures.service_integration.create
      Webhookdb::Services.service_instance(sint).create_table
      expect do
        Webhookdb.publish(
          "webhookdb.serviceintegration.webhook",
          sint.id,
          {
            headers: {},
            body: {"my_id" => "xyz", "at" => "Thu, 30 Jul 2015 21:12:33 +0000"},
          },
        )
      end.to perform_async_job(Webhookdb::Async::ProcessWebhook)
      expect(Webhookdb::Services.service_instance(sint).dataset.all).to have_length(1)
    end
  end

  describe "ResetCodeCreateDispatch" do
    it "sends an sms for an sms reset code" do
      customer = Webhookdb::Fixtures.customer(phone: "12223334444").create
      expect do
        customer.add_reset_code(token: "12345", transport: "sms")
      end.to perform_async_job(Webhookdb::Async::ResetCodeCreateDispatch)

      expect(Webhookdb::Message::Delivery.all).to contain_exactly(
        have_attributes(
          template: "verification",
          transport_type: "sms",
          to: "12223334444",
          bodies: contain_exactly(
            have_attributes(content: "Your Webhookdb verification code is: 12345"),
          ),
        ),
      )
    end

    it "sends an email for an email reset code" do
      customer = Webhookdb::Fixtures.customer(email: "maryjane@lithic.tech").create
      expect do
        customer.add_reset_code(token: "12345", transport: "email")
      end.to perform_async_job(Webhookdb::Async::ResetCodeCreateDispatch)

      expect(Webhookdb::Message::Delivery.all).to contain_exactly(
        have_attributes(
          template: "verification",
          transport_type: "email",
          to: "maryjane@lithic.tech",
          bodies: include(
            have_attributes(content: match(/12345/)),
          ),
        ),
      )
    end
  end
end
