# frozen_string_literal: true

require "amigo/durable_job"
require "webhookdb/async"
require "webhookdb/messages/specs"
require "rspec/eventually"

RSpec.describe "webhookdb async jobs", :async, :db, :do_not_defer_events, :no_transaction_check do
  before(:all) do
    Webhookdb::Async.setup_tests
    Sidekiq::Testing.inline!
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
      req = Webhookdb::Replicator::Fake.stub_backfill_request(page1_items)
      Webhookdb::Replicator.create(sint).create_table
      expect do
        Amigo.publish(
          "webhookdb.serviceintegration.backfill", sint.id,
        )
      end.to perform_async_job(Webhookdb::Jobs::Backfill)
      expect(req).to have_been_made
      Webhookdb::Replicator.create(sint).readonly_dataset do |ds|
        expect(ds.all).to have_length(2)
      end
    ensure
      sint.organization.remove_related_database
    end

    it "can specify incremental" do
      sint = Webhookdb::Fixtures.service_integration.create(backfill_key: "bfkey", backfill_secret: "bfsek")
      sint.organization.prepare_database_connections
      req = Webhookdb::Replicator::Fake.stub_backfill_request(page1_items)
      Webhookdb::Replicator.create(sint).create_table
      expect do
        Amigo.publish(
          "webhookdb.serviceintegration.backfill", sint.id, {incremental: true},
        )
      end.to perform_async_job(Webhookdb::Jobs::Backfill)
      expect(req).to have_been_made
      Webhookdb::Replicator.create(sint).readonly_dataset do |ds|
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
      Webhookdb::Replicator.create(sint).admin_dataset do |ds|
        expect(ds.db).to be_table_exists(sint&.table_name)
      end
    ensure
      org.remove_related_database
    end
  end

  describe "CreateStripeCustomer" do
    it "registers the customer" do
      req = stub_request(:post, "https://api.stripe.com/v1/customers").
        to_return(body: load_fixture_data("stripe/customer_create", raw: true))
      expect do
        Webhookdb::Fixtures.organization.create(stripe_customer_id: "")
      end.to perform_async_job(Webhookdb::Jobs::CreateStripeCustomer)
      expect(req).to have_been_made
    end

    it "noops if billing is disabled" do
      Webhookdb::Subscription.disable_billing = true
      expect do
        Webhookdb::Fixtures.organization.create(stripe_customer_id: "")
      end.to perform_async_job(Webhookdb::Jobs::CreateStripeCustomer)
    ensure
      Webhookdb::Subscription.reset_configuration
    end
  end

  describe "CustomerCreatedNotifyInternal" do
    it "publishes a developer alert" do
      expect do
        Webhookdb::Fixtures.customer.create
      end.to perform_async_job(Webhookdb::Jobs::CustomerCreatedNotifyInternal).
        and(publish("webhookdb.developeralert.emitted").with_payload(
              contain_exactly(include("subsystem" => "Customer Created")),
            ))
    end
  end

  describe "deprecated jobs" do
    it "exist as job classes" do
      expect(defined? Webhookdb::Jobs::Test::DeprecatedJob).to be_truthy
      expect(Webhookdb::Jobs::Test::DeprecatedJob).to respond_to(:perform_async)
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

  describe "DurableJobRecheckPoller" do
    before(:all) do
      Amigo::DurableJob.reset_configuration
    end

    it "runs DurableJob.poll_jobs" do
      Amigo::DurableJob.reset_configuration(enabled: true)
      # Ensure polling is called, but it should be early-outed.
      # rubocop:disable RSpec/VerifiedDoubles
      expect(Sidekiq::RetrySet).to receive(:new).and_return(double(size: 1000))
      # rubocop:enable RSpec/VerifiedDoubles
      Webhookdb::Jobs::DurableJobRecheckPoller.new.perform
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

  describe "NextpaxSyncPropertyChanges" do
    let(:org) { Webhookdb::Fixtures.organization.create }
    let(:fac) { Webhookdb::Fixtures.service_integration(organization: org) }
    let(:auth_sint) do
      fac.create(
        service_name: "nextpax_auth_v1",
        backfill_key: "client_id",
        backfill_secret: "client_secret",
        last_backfilled_at: Time.now,
        webhook_secret: {access_token: "123", expires_in: 1000}.to_json,
      )
    end
    let(:dep_sint) { fac.depending_on(auth_sint).create(service_name: "nextpax_property_manager_v1").refresh }
    let(:sint) { fac.depending_on(dep_sint).create(service_name: "nextpax_property_v1").refresh }

    before(:all) do
      Webhookdb::Nextpax.reset_configuration
    end

    it "polls nextpax for property changes" do
      last_backfilled_at = 4.hours.ago
      sint.update(last_backfilled_at:)

      req = stub_request(:get, "https://fake-url.com/api/v1/content/property-changes?fromTimestamp=#{last_backfilled_at.utc.iso8601}&limit=20&offset=0").
        to_return(
          status: 200,
          body: {
            data: [],
            request_id: "djalksfjsdakjgasdf",
          }.to_json,
          headers: {"Content-Type" => "application/json"},
        )
      Webhookdb::Jobs::NextpaxSyncPropertyChanges.new.perform
      expect(req).to have_been_made
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
      Webhookdb::Replicator.create(sint).create_table
      expect do
        Amigo.publish(
          "webhookdb.serviceintegration.webhook",
          sint.id,
          {
            headers: {},
            body: {"my_id" => "xyz", "at" => "Thu, 30 Jul 2015 21:12:33 +0000"},
            request_path: "/abc",
            request_method: "POST",
          },
        )
      end.to perform_async_job(Webhookdb::Jobs::ProcessWebhook)
      Webhookdb::Replicator.create(sint).readonly_dataset do |ds|
        expect(ds.all).to have_length(1)
      end
    ensure
      sint.organization.remove_related_database
    end

    it "can calculate semaphore details" do
      sint = Webhookdb::Fixtures.service_integration.create
      sint.organization.update(job_semaphore_size: 6)
      j = Webhookdb::Jobs::ProcessWebhook.new
      j.before_perform({"id" => "1", "name" => "topic", "payload" => [sint.id]})
      expect(j).to have_attributes(semaphore_key: "semaphore-procwebhook-#{sint.organization_id}", semaphore_size: 6)
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

    it "noops if the migration is already finished" do
      org = Webhookdb::Fixtures.organization.create
      org.prepare_database_connections
      dbinfo = Webhookdb::Organization::DbBuilder.new(org).prepare_database_connections
      dbm = Webhookdb::Organization::DatabaseMigration.enqueue(
        admin_connection_url_raw: dbinfo.admin_url,
        readonly_connection_url_raw: dbinfo.readonly_url,
        public_host: "",
        started_by: nil,
        organization: org,
      )
      dbm.update(finished_at: Time.now)
      expect do
        dbm.publish_immediate("created", dbm.id)
      end.to perform_async_job(Webhookdb::Jobs::OrganizationDatabaseMigrationRun)
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

  describe "RenewGoogleWatchChannels and RenewWatchChannel" do
    let(:org) { Webhookdb::Fixtures.organization.create }
    let(:fac) { Webhookdb::Fixtures.service_integration(organization: org) }
    let(:cal_list_sint) { fac.stable_encryption_secret.create(service_name: "google_calendar_list_v1") }
    let(:cal_list_svc) { cal_list_sint.replicator }
    let(:cal_sint) { fac.depending_on(cal_list_sint).create(service_name: "google_calendar_v1") }
    let(:cal_svc) { cal_sint.replicator }

    before(:each) do
      org.prepare_database_connections
      cal_list_svc.create_table
      cal_svc.create_table
    end

    after(:each) do
      org.remove_related_database
    end

    def refreshed(row)
      return svc.readonly_dataset { |ds| ds[pk: row.fetch(:pk)] }
    end

    it "performs bulk update on google replicator watches" do
      before_cutoff = Time.now + 2.hours
      after_cutoff = Time.now + 2.weeks
      cal_list_svc.admin_dataset do |ds|
        ds.returning(Sequel.lit("*")).insert(
          data: "{}",
          row_updated_at: Time.now,
          encrypted_refresh_token: "lGfCermPAzJuhsbRalipbg==",
          external_owner_id: "owner1",
          watch_channel_id: "chan_id",
          watch_channel_expiration: after_cutoff,
        ).first
      end
      cal_list_svc.force_set_oauth_access_token("owner1", "asdfghjkl4567")
      cal_row = cal_svc.admin_dataset do |ds|
        ds.returning(Sequel.lit("*")).insert(
          data: "{}",
          compound_identity: "owner1_x",
          google_id: "x",
          external_owner_id: "owner1",
          events_watch_channel_id: "events_chan_id",
          events_watch_channel_expiration: before_cutoff,
          events_watch_resource_id: "res_id",
        ).first
      end
      cal_watch_req = stub_request(:post, "https://www.googleapis.com/calendar/v3/calendars/x/events/watch").
        with(
          headers: {"Authorization" => "Bearer asdfghjkl4567"},
          body: hash_including(
            :id, # this value is randomly generated so we can't predict it, but it should be there
            token: {external_owner_id: "owner1"}.to_json,
            type: "webhook",
            address: cal_svc.webhook_endpoint,
          ),
        ).
        to_return(
          status: 200,
          headers: {"Content-Type" => "application/json"},
          body: {
            kind: "api#channel",
            id: "id_for_channel",
            resourceId: "id_for_watched_resource",
            resourceUri: "version_specific_id",
            expiration: "1672864942219",
          }.to_json,
        )
      cal_stop_req = stub_request(:post, "https://www.googleapis.com/calendar/v3/channels/stop").
        with(
          headers: {"Authorization" => "Bearer asdfghjkl4567"},
          body: {id: "events_chan_id", resourceId: "res_id"}.to_json,
        ).
        to_return(status: 200, body: "")

      # Test the scheduled job, which enques sub-jobs, and the evaluation of these sub-jobs.
      # Since we test RenewWatchChannel via RenewGoogleWatchChannels anyway,
      # this seems fine.
      # Other bulk channel renew/enqueue jobs can be tested at the publishing level,
      # without the API request portion.
      expect do
        expect do
          Webhookdb::Jobs::RenewGoogleWatchChannels.new.perform
        end.to publish(
          "webhookdb.serviceintegration.renewwatchchannel",
          contain_exactly(cal_sint.id, include("row_pk" => cal_row.fetch(:pk))),
        )
      end.to perform_async_job(Webhookdb::Jobs::RenewWatchChannel)

      expect(cal_watch_req).to have_been_made
      expect(cal_stop_req).to have_been_made

      refreshed_cal_row = cal_svc.readonly_dataset { |ds| ds[pk: cal_row.fetch(:pk)] }
      expect(refreshed_cal_row).to include(
        events_watch_channel_expiration: match_time("2023-01-04 20:42:22.219 +0000"),
        events_watch_channel_id: "id_for_channel",
      )
    end
  end

  describe "ReplicationMigration" do
    let(:fake_sint) { Webhookdb::Fixtures.service_integration.create }
    let(:o) { fake_sint.organization }
    let(:fake) { fake_sint.replicator }

    before(:each) do
      o.prepare_database_connections
      fake.create_table
    end

    after(:each) do
      o.remove_related_database
    end

    it "migrates the org replication tables" do
      fake.admin_dataset do |ds|
        expect(ds.columns).to contain_exactly(:pk, :my_id, :at, :data)
        ds.db << "ALTER TABLE #{fake_sint.table_name} DROP COLUMN at"
      end
      Webhookdb::Jobs::ReplicationMigration.new.perform(o.id)
      fake.admin_dataset do |ds|
        expect(ds.columns).to contain_exactly(:pk, :my_id, :at, :data)
      end
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
        Amigo.publish(
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
      expect(Webhookdb::Jobs::SyncTargetRunSync).to receive(:perform_in).with(be_positive, never_run.id)
      Webhookdb::Jobs::SyncTargetEnqueueScheduled.new.perform
    end
  end

  describe "SyncTargetRunSync" do
    let(:sint) { Webhookdb::Fixtures.service_integration.create }

    before(:each) do
      sint.organization.prepare_database_connections
      sint.replicator.create_table
    end

    after(:each) do
      sint.organization.remove_related_database
    end

    it "runs the sync" do
      stgt = Webhookdb::Fixtures.sync_target(service_integration: sint).postgres.create
      Webhookdb::Jobs::SyncTargetRunSync.new.perform(stgt.id)
      expect(stgt.refresh).to have_attributes(last_synced_at: be_within(5).of(Time.now))
    end

    it "noops if a sync is in progress" do
      orig_sync = 3.hours.ago
      stgt = Webhookdb::Fixtures.sync_target(service_integration: sint).postgres.create(last_synced_at: orig_sync)
      Sequel.connect(Webhookdb::Postgres::Model.uri) do |otherconn|
        Sequel::AdvisoryLock.new(otherconn, Webhookdb::SyncTarget::ADVISORY_LOCK_KEYSPACE, stgt.id).with_lock do
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
        Webhookdb::Jobs::SendWebhook.new.perform(Amigo::Event.create(
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
          Amigo.publish(
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
          Amigo.publish(
            "webhookdb.webhooksubscription.test", webhook_sub.id,
          )
        end.to perform_async_job(Webhookdb::Jobs::SendTestWebhook)
        expect(req).to have_been_made
      end
    end
  end

  describe "SponsyScheduledBackfill" do
    it "enqueues cascading backfill job for all theranest auth integrations" do
      auth_sint = Webhookdb::Fixtures.service_integration.create(service_name: "sponsy_publication_v1")
      expect do
        Webhookdb::Jobs::SponsyScheduledBackfill.new.perform
      end.to publish(
        "webhookdb.serviceintegration.backfill",
        [auth_sint.id, {"cascade" => true, "incremental" => true}],
      )
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
