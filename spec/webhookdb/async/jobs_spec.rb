# frozen_string_literal: true

require "webhookdb/async"
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
      sint = Webhookdb::Fixtures.service_integration.create(backfill_key: "bfkey", backfill_secret: "bfsek")
      sint.organization.prepare_database_connections
      req = Webhookdb::Services::Fake.stub_backfill_request(page1_items)
      Webhookdb::Services.service_instance(sint).create_table
      expect do
        Webhookdb.publish(
          "webhookdb.serviceintegration.backfill", sint.id,
        )
      end.to perform_async_job(Webhookdb::Jobs::Backfill)
      expect(req).to have_been_made
      Webhookdb::Services.service_instance(sint).readonly_dataset do |ds|
        expect(ds.all).to have_length(2)
      end
    ensure
      sint.organization.remove_related_database
    end

    it "can specify incremental" do
      sint = Webhookdb::Fixtures.service_integration.create(backfill_key: "bfkey", backfill_secret: "bfsek")
      sint.organization.prepare_database_connections
      req = Webhookdb::Services::Fake.stub_backfill_request(page1_items)
      Webhookdb::Services.service_instance(sint).create_table
      expect do
        Webhookdb.publish(
          "webhookdb.serviceintegration.backfill", sint.id, {incremental: true},
        )
      end.to perform_async_job(Webhookdb::Jobs::Backfill)
      expect(req).to have_been_made
      Webhookdb::Services.service_instance(sint).readonly_dataset do |ds|
        expect(ds.all).to have_length(2)
      end
    ensure
      sint.organization.remove_related_database
    end
  end

  describe "CreateMirrorTable" do
    it "creates the table for the service integration" do
      org = Webhookdb::Fixtures.organization.create
      org.prepare_database_connections
      sint = nil
      expect do
        sint = Webhookdb::Fixtures.service_integration(organization: org).create
      end.to perform_async_job(Webhookdb::Jobs::CreateMirrorTable)

      expect(sint).to_not be_nil
      Webhookdb::Services.service_instance(sint).admin_dataset do |ds|
        expect(ds.db).to be_table_exists(sint&.table_name)
      end
    ensure
      org.remove_related_database
    end
  end

  describe "deprecated jobs" do
    it "exist as job classes, and noop" do
      expect(defined? Webhookdb::Jobs::Test::DeprecatedJob).to be_truthy

      logs = capture_logs_from(Webhookdb::Async::JobLogger.logger, level: :info) do
        Webhookdb::Jobs::Test::DeprecatedJob.new.perform
      end
      expect(logs.to_s).to include("deprecated job, remove in the future")
    end
  end

  describe "MessageDispatched", messaging: true do
    it "sends the delivery on create" do
      email = "wibble@lithic.tech"

      expect do
        Webhookdb::Messages::Testers::Basic.new.dispatch(email)
      end.to perform_async_job(Webhookdb::Jobs::MessageDispatched)

      expect(Webhookdb::Message::Delivery).to have_row(to: email).
        with_attributes(transport_message_id: be_a(String))
    end
  end

  describe "PrepareDatabaseConnections" do
    let(:org) { Webhookdb::Fixtures.organization.create }

    after(:each) do
      org.remove_related_database
      Webhookdb::Organization::DbBuilder.reset_configuration
    end

    it "creates the database urls for the organization" do
      expect do
        org.publish_immediate("create", org.id, org.values)
      end.to perform_async_job(Webhookdb::Jobs::PrepareDatabaseConnections)

      org.refresh
      expect(org).to have_attributes(
        admin_connection_url: start_with("postgres://"),
        readonly_connection_url: start_with("postgres://"),
        public_host: be_blank,
      )
    end

    it "sets the public host" do
      fixture = load_fixture_data("cloudflare/create_zone_dns")
      fixture["result"].merge!("type" => "CNAME", "name" => "myorg2.db.testing.dev")
      req = stub_request(:post, "https://api.cloudflare.com/client/v4/zones/testdnszoneid/dns_records").
        to_return(status: 200, body: fixture.to_json)
      Webhookdb::Organization::DbBuilder.create_cname_for_connection_urls = true

      expect do
        org.publish_immediate("create", org.id, org.values)
      end.to perform_async_job(Webhookdb::Jobs::PrepareDatabaseConnections)

      expect(req).to have_been_made

      org.refresh
      expect(org).to have_attributes(
        admin_connection_url: start_with("postgres://"),
        readonly_connection_url: start_with("postgres://"),
        public_host: eq("myorg2.db.testing.dev"),
      )
    end
  end

  describe "ProcessWebhook" do
    it "passes the payload off to the processor" do
      sint = Webhookdb::Fixtures.service_integration.create
      sint.organization.prepare_database_connections
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
      end.to perform_async_job(Webhookdb::Jobs::ProcessWebhook)
      Webhookdb::Services.service_instance(sint).readonly_dataset do |ds|
        expect(ds.all).to have_length(1)
      end
    ensure
      sint.organization.remove_related_database
    end
  end

  describe "ResetCodeCreateDispatch" do
    it "sends an email for an email reset code" do
      customer = Webhookdb::Fixtures.customer(email: "maryjane@lithic.tech").create
      expect do
        customer.add_reset_code(token: "12345", transport: "email")
      end.to perform_async_job(Webhookdb::Jobs::ResetCodeCreateDispatch)
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

  describe "SendInvite" do
    it "sends an email with an invitation code" do
      customer = Webhookdb::Fixtures.customer(email: "lucy@lithic.tech").create
      org = Webhookdb::Fixtures.organization.create
      membership = Webhookdb::OrganizationMembership.create(customer:, organization: org,
                                                            invitation_code: "join-abcxyz",)
      expect do
        Webhookdb.publish(
          "webhookdb.organizationmembership.invite", membership.id,
        )
      end.to perform_async_job(Webhookdb::Jobs::SendInvite)
      expect(Webhookdb::Message::Delivery.first).to have_attributes(
        template: "invite",
        transport_type: "email",
        to: "lucy@lithic.tech",
        bodies: include(
          have_attributes(content: match(/join-abcxyz/)),
        ),
      )
    end
  end

  describe "TrimLoggedWebhooks" do
    it "runs LoggedWebhooks.trim_table" do
      old = Webhookdb::Fixtures.logged_webhook.ancient.create
      newer = Webhookdb::Fixtures.logged_webhook.create
      Webhookdb::Jobs::TrimLoggedWebhooks.new.perform
      expect(Webhookdb::LoggedWebhook.all).to have_same_ids_as(newer)
    end
  end

  describe "TwilioScheduledBackfill" do
    it "enqueues backfill job for all twilio service integrations" do
      twilio_sint = Webhookdb::Fixtures.service_integration.create(
        service_name: "twilio_sms_v1",
      )
      expect do
        Webhookdb::Jobs::TwilioScheduledBackfill.new.perform
      end.to publish("webhookdb.serviceintegration.backfill", [twilio_sint.id, {"incremental" => true}])
    end
  end
end
