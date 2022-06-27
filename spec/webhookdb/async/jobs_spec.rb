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

  describe "CustomerCreatedNotifyInternal" do
    it "publishes a developer alert" do
      expect do
        Webhookdb::Fixtures.customer.create
      end.to perform_async_job(Webhookdb::Jobs::CustomerCreatedNotifyInternal).
        and(publish("webhookdb.developeralert.emitted").with_payload(
              match_array([include("subsystem" => "Customer Created")]),
            ))
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

  describe "DeveloperAlertHandle", :slack do
    it "posts to Slack" do
      alert = Webhookdb::DeveloperAlert.new(
        subsystem: "Sales",
        emoji: ":dollar:",
        fallback: "message",
        fields: [
          {title: "Greeting", value: "hello", short: false},
        ],
      )
      expect do
        alert.emit
      end.to perform_async_job(Webhookdb::Jobs::DeveloperAlertHandle)
      expect(Webhookdb::Slack.http_client.posts).to have_length(1)
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
      Webhookdb.reset_configuration
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

  describe "OrganizationDatabaseMigrationRun" do
    it "starts running the migration on creation" do
      org = Webhookdb::Fixtures.organization.create
      org.prepare_database_connections
      dbinfo = Webhookdb::Organization::DbBuilder.new(org).prepare_database_connections
      expect do
        Webhookdb::Organization::DatabaseMigration.enqueue(
          admin_connection_url_raw: dbinfo.admin_url,
          readonly_connection_url_raw: dbinfo.readonly_url,
          public_host: "",
          started_by: nil,
          organization: org,
        )
      end.to perform_async_job(Webhookdb::Jobs::OrganizationDatabaseMigrationRun)
      expect(Webhookdb::Organization::DatabaseMigration.first).to have_attributes(
        started_at: match_time(Time.now).within(5),
      )
    end
  end

  describe "OrganizationDatabaseMigrationNotifyStarted" do
    it "sends an email when the migration has started" do
      org = Webhookdb::Fixtures.organization.create
      admin1 = Webhookdb::Fixtures.customer.admin_in_org(org).create
      admin2 = Webhookdb::Fixtures.customer.admin_in_org(org).create
      Webhookdb::Fixtures.customer.verified_in_org(org).create
      dbm = Webhookdb::Fixtures.organization_database_migration(organization: org).with_urls.create
      expect do
        dbm.update(started_at: Time.now)
      end.to perform_async_job(Webhookdb::Jobs::OrganizationDatabaseMigrationNotifyStarted)
      expect(Webhookdb::Message::Delivery.all).to contain_exactly(
        have_attributes(
          template: "org_database_migration_started",
          to: admin1.email,
        ),
        have_attributes(
          template: "org_database_migration_started",
          to: admin2.email,
        ),
      )
    end
  end

  describe "OrganizationDatabaseMigrationFinished" do
    it "sends an email when the migration has finished" do
      org = Webhookdb::Fixtures.organization.create
      admin1 = Webhookdb::Fixtures.customer.admin_in_org(org).create
      admin2 = Webhookdb::Fixtures.customer.admin_in_org(org).create
      Webhookdb::Fixtures.customer.verified_in_org(org).create
      dbm = Webhookdb::Fixtures.organization_database_migration(organization: org).with_urls.create
      expect do
        dbm.update(finished_at: Time.now)
      end.to perform_async_job(Webhookdb::Jobs::OrganizationDatabaseMigrationNotifyFinished)
      expect(Webhookdb::Message::Delivery.all).to contain_exactly(
        have_attributes(
          template: "org_database_migration_finished",
          to: admin1.email,
        ),
        have_attributes(
          template: "org_database_migration_finished",
          to: admin2.email,
        ),
      )
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
      membership = Webhookdb::Fixtures.organization_membership.
        customer(email: "lucy@lithic.tech").
        invite.
        code("join-abcxyz").
        create
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

  describe "SyncTargetEnqueueScheduled" do
    it "runs sync targets that are due" do
      never_run = Webhookdb::Fixtures.sync_target.create
      run_recently = Webhookdb::Fixtures.sync_target.create(last_synced_at: Time.now)
      expect(Webhookdb::Jobs::SyncTargetRunSync).to receive(:perform_async).with(never_run.id)
      Webhookdb::Jobs::SyncTargetEnqueueScheduled.new.perform
    end
  end

  describe "SyncTargetRunSync" do
    let(:sint) { Webhookdb::Fixtures.service_integration.create }

    before(:each) do
      sint.organization.prepare_database_connections
      sint.service_instance.create_table
    end

    after(:each) do
      sint.organization.remove_related_database
    end

    it "runs the sync" do
      stgt = Webhookdb::Fixtures.sync_target(service_integration: sint).postgres.create
      Webhookdb::Jobs::SyncTargetRunSync.new.perform(stgt.id)
      expect(stgt.refresh).to have_attributes(last_synced_at: be_within(5).of(Time.now))
    end

    it "noops if a sync is in progress", db: :no_transaction do
      orig_sync = 3.hours.ago
      stgt = Webhookdb::Fixtures.sync_target(service_integration: sint).postgres.create(last_synced_at: orig_sync)
      Sequel.connect(Webhookdb::Postgres::Model.uri) do |otherconn|
        otherconn.transaction(rollback: :always) do
          otherconn[:sync_targets].where(id: stgt.id).lock_style("FOR UPDATE").first
          Webhookdb::Jobs::SyncTargetRunSync.new.perform(stgt.id)
        end
      end
      expect(stgt.refresh).to have_attributes(last_synced_at: match_time(orig_sync))
    end
  end

  describe "Webhook Subscription jobs" do
    let!(:sint) { Webhookdb::Fixtures.service_integration.create }
    let!(:webhook_sub) do
      Webhookdb::Fixtures.webhook_subscription.create(service_integration: sint)
    end

    describe "SendWebhook" do
      it "sends request to correct endpoint" do
        req = stub_request(:post, webhook_sub.deliver_to_url).to_return(status: 200, body: "", headers: {})
        Webhookdb::Jobs::SendWebhook.new.perform(Webhookdb::Event.create(
          "",
          [
            sint.id,
            {
              row: {},
              external_id_column: "external id column",
              external_id: "external id",
            },
          ],
        ).as_json)
        expect(req).to have_been_made
      end

      it "does not query for deactivated subscriptions" do
        webhook_sub.deactivate.save_changes
        expect do
          Webhookdb.publish(
            "webhookdb.serviceintegration.rowupsert",
            sint.id,
            {
              row: {},
              external_id_column: "external id column",
              external_id: "external id",
            },
          )
        end.to perform_async_job(Webhookdb::Jobs::SendWebhook)
        expect(Webhookdb::WebhookSubscription::Delivery.all).to be_empty
      end
    end

    describe "SendTestWebhook" do
      it "sends request to correct endpoint" do
        req = stub_request(:post, webhook_sub.deliver_to_url).to_return(status: 200, body: "", headers: {})
        expect do
          Webhookdb.publish(
            "webhookdb.webhooksubscription.test", webhook_sub.id,
          )
        end.to perform_async_job(Webhookdb::Jobs::SendTestWebhook)
        expect(req).to have_been_made
      end
    end
  end

  describe "TheranestScheduledBackfill" do
    it "enqueues cascading backfill job for all theranest auth integrations" do
      auth_sint = Webhookdb::Fixtures.service_integration.create(
        service_name: "theranest_auth_v1",
      )
      expect do
        Webhookdb::Jobs::TheranestScheduledBackfill.new.perform
      end.to publish("webhookdb.serviceintegration.backfill", [auth_sint.id, {"cascade" => true}])
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

  describe "WebhookdbResourceNotifyIntegrations" do
    it "POSTs to webhookdb service integrations on change" do
      sint = Webhookdb::Fixtures.service_integration.create(service_name: "webhookdb_customer_v1")

      req = stub_request(:post, "http://localhost:18001/v1/service_integrations/#{sint.opaque_id}").
        with(body: hash_including("id", "created_at")).
        to_return(status: 202, body: "ok")

      expect do
        Webhookdb::Fixtures.customer.create
      end.to perform_async_job(Webhookdb::Jobs::WebhookdbResourceNotifyIntegrations)

      expect(req).to have_been_made
    end
  end
end
