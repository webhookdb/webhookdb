# frozen_string_literal: true

require "support/shared_examples_for_replicators"

RSpec.describe Webhookdb::Replicator::MicrosoftCalendarUserV1, :db do
  let(:org) { Webhookdb::Fixtures.organization.create }
  let(:fac) { Webhookdb::Fixtures.service_integration(organization: org) }
  let(:sint) { fac.stable_encryption_secret.create(service_name: "microsoft_calendar_user_v1") }
  let(:svc) { sint.replicator }
  let(:cal_sint) { fac.depending_on(sint).create(service_name: "microsoft_calendar_v1") }
  let(:cal_svc) { cal_sint.replicator }
  let(:event_sint) { fac.depending_on(cal_sint).create(service_name: "microsoft_calendar_event_v1") }
  let(:event_svc) { event_sint.replicator }
  let(:calview_start_enc) { ERB::Util.url_encode(Webhookdb::MicrosoftCalendar.calendar_view_start_time.iso8601) }
  let(:calview_end_enc) { ERB::Util.url_encode(Webhookdb::MicrosoftCalendar.calendar_view_end_time.iso8601) }
  let(:calview_query_start_end) { "endDateTime=#{calview_end_enc}&startDateTime=#{calview_start_enc}" }

  def insert_cal_user_row(**more)
    if (rtok = more.delete(:refresh_token))
      more[:encrypted_refresh_token] = Webhookdb::Crypto.encrypt_value(
        Webhookdb::Crypto::Boxed.from_b64(Webhookdb::Fixtures::ServiceIntegrations::STABLE_ENC_SECRET),
        Webhookdb::Crypto::Boxed.from_raw(rtok),
      ).base64
    end
    svc.admin_dataset do |ds|
      inserted = ds.returning(Sequel.lit("*")).
        insert(
          data: "{}",
          row_updated_at: Time.now,
          **more,
        )
      return inserted.first
    end
  end

  def force_set_oauth_access_token(microsoft_user_id, access_token="randtok-#{SecureRandom.hex(2)}")
    svc.force_set_oauth_access_token(microsoft_user_id, access_token)
  end

  def stub_subscription_request(expiration:, subscription_id: nil, status: 200, body: nil, method: :post)
    url = if subscription_id.nil?
            "https://graph.microsoft.com/v1.0/subscriptions"
          else
            "https://graph.microsoft.com/v1.0/subscriptions/#{subscription_id}"
          end
    body ||= {
      id: subscription_id || "subscription_id",
      expirationDateTime: expiration,
    }

    return stub_request(method, url).to_return(status:, headers: json_headers, body: body.to_json)
  end

  it_behaves_like "a replicator", "microsoft_calendar_user_v1" do
    let(:sint) { super() }
    let(:body) do
      JSON.parse(<<~J)
        {
          "type": "__WHDB_UNIT_TEST",
          "microsoft_user_id": "123",
          "refresh_token":"asdfghjkl4567"
        }
      J
    end
    let(:expected_row) do
      include(
        :pk,
        data: {},
        encrypted_refresh_token: "lGfCermPAzJuhsbRalipbg==",
        microsoft_user_id: "123",
        row_created_at: match_time(:now),
        row_updated_at: match_time(:now),
      )
    end
    let(:supports_row_diff) { false }
  end

  it_behaves_like "a replicator with dependents", "microsoft_calendar_user_v1", "microsoft_calendar_v1" do
    let(:sint) { super() }
    let(:body) do
      JSON.parse(<<~J)
        {
          "type": "__WHDB_UNIT_TEST",
          "microsoft_user_id": "123",
          "refresh_token":"asdfghjkl4567"
        }
      J
    end
    let(:can_track_row_changes) { false }
    let(:expected_insert) do
      {
        data: "{}",
        encrypted_refresh_token: "lGfCermPAzJuhsbRalipbg==",
        microsoft_user_id: "123",
        row_created_at: match_time(:now),
        row_updated_at: match_time(:now),
      }
    end
  end

  describe "upsert_webhook" do
    before(:each) do
      org.prepare_database_connections
      svc.create_table
      cal_svc.create_table
      event_svc.create_table
      Webhookdb::MicrosoftCalendar.list_page_size = 1
    end

    after(:each) do
      org.remove_related_database
    end

    let(:calendar_page_1_response) do
      {"value" => [
         {"id" => "cal1",
          "name" => "Calendar",
          "color" => "auto",
          "owner" => {"name" => "Natalie  Edson", "address" => "natalie@example.com"},
          "canEdit" => true,
          "canShare" => true,
          "hexColor" => "",
          "changeKey" => "gKa77joca0mp9eqf5b7xmAAAAAACYg==",
          "isRemovable" => false,
          "isDefaultCalendar" => false,
          "canViewPrivateItems" => true,
          "isTallyingResponses" => true,
          "defaultOnlineMeetingProvider" => "teamsForBusiness",
          "allowedOnlineMeetingProviders" => ["teamsForBusiness"],},
       ],
       "@odata.nextLink" => "https://graph.microsoft.com/v1.0/me/calendars?%24top=1&%24skip=1",}
    end
    let(:calendar_page_2_response) do
      {"value" => [
        {"id" => "cal2",
         "name" => "United States holidays",
         "color" => "auto",
         "owner" => {"name" => "Natalie  Edson", "address" => "natalie@natalielithic.onmicrosoft.com"},
         "canEdit" => false,
         "canShare" => false,
         "hexColor" => "",
         "changeKey" => "gKa77joca0mp9eqf5b7xmAAAAAACmw==",
         "isRemovable" => true,
         "isDefaultCalendar" => false,
         "canViewPrivateItems" => true,
         "isTallyingResponses" => false,
         "defaultOnlineMeetingProvider" => "unknown",
         "allowedOnlineMeetingProviders" => [],},
      ]}
    end
    let(:event_page_1_response) do
      {"value" => [{"id" => "ev1"}],
       "@odata.nextLink" => "#{base_event_url('cal1')}&%24skip=1",}
    end
    let(:event_page_2_response) { {"value" => [{"id" => "ev2"}]} }
    let(:event_page_3_response) do
      {"value" => [{"id" => "ev3"}],
       "@odata.nextLink" => "#{base_event_url('cal2')}&%24skip=1",}
    end
    let(:event_page_4_response) { {"value" => [{"id" => "ev4"}]} }

    def base_event_url(cal_id) = "https://graph.microsoft.com/v1.0/me/calendars/#{cal_id}/calendarView?$top=1&#{calview_query_start_end}"

    def stub_calendar_requests(access_token)
      headers = {"Authorization" => "Bearer #{access_token}"}
      base_url = "https://graph.microsoft.com/v1.0/me/calendars?$top=1"
      return [
        stub_request(:get, base_url).with(headers:).to_return(
          status: 200, body: calendar_page_1_response.to_json, headers: json_headers,
        ),
        stub_request(:get, "#{base_url}&%24skip=1").with(headers:).to_return(
          status: 200, body: calendar_page_2_response.to_json, headers: json_headers,
        ),
      ]
    end

    def stub_event_requests(access_token)
      headers = {"Authorization" => "Bearer #{access_token}"}
      return [
        stub_request(:get, base_event_url("cal1")).with(headers:).to_return(
          status: 200, body: event_page_1_response.to_json, headers: json_headers,
        ),
        stub_request(:get, "#{base_event_url('cal1')}&%24skip=1").with(headers:).to_return(
          status: 200, body: event_page_2_response.to_json, headers: json_headers,
        ),
        stub_request(:get, base_event_url("cal2")).with(headers:).to_return(
          status: 200, body: event_page_3_response.to_json, headers: json_headers,
        ),
        stub_request(:get, "#{base_event_url('cal2')}&%24skip=1").with(headers:).to_return(
          status: 200, body: event_page_4_response.to_json, headers: json_headers,
        ),
      ]
    end

    describe "change notifications from microsoft" do
      let(:notification_body) do
        JSON.parse(<<~J)
          {
            "value": [{
              "@odata.type": "#microsoft.graph.changeNotification",
              "changeType": "String",
              "clientState": "String",
              "encryptedContent": {
                "@odata.type": "microsoft.graph.changeNotificationEncryptedContent"
              },
              "id": "String (identifier)",
              "lifecycleEvent": "String",
              "resource": "String",
              "resourceData": {
                "@odata.type": "microsoft.graph.resourceData"
              },
              "subscriptionExpirationDateTime": "String (timestamp)",
              "subscriptionId": "sub_id",
              "tenantId": "Guid"
            }]
          }
        J
      end

      it "finds user row associated with the subscription and triggers full sync" do
        insert_cal_user_row(refresh_token: "refreshtok", microsoft_user_id: "456", events_subscription_id: "sub_id")
        force_set_oauth_access_token("456", "acctok")
        cal_reqs = stub_calendar_requests("acctok")
        event_reqs = stub_event_requests("acctok")
        svc.upsert_webhook_body(notification_body)
        expect(cal_reqs).to all(have_been_made)
        expect(event_reqs).to all(have_been_made)
      end

      it "raise an error if there is no calendar user associated with the subscription_id" do
        expect do
          svc.upsert_webhook_body(notification_body)
        end.to raise_error(Webhookdb::InvalidPostcondition)
      end
    end

    describe "requests from the customer" do
      it "responds to `LINKED` request by inserting row and triggering full sync and creating event subscription" do
        body = {"refresh_token" => "refrok", "microsoft_user_id" => "456", "type" => "LINKED"}
        force_set_oauth_access_token("456", "acctok")
        cal_reqs = stub_calendar_requests("acctok")
        event_reqs = stub_event_requests("acctok")
        expiration = Time.now + 4300.minutes
        subscription_req = stub_subscription_request(expiration:)
        svc.upsert_webhook_body(body)
        expect(cal_reqs).to all(have_been_made)
        expect(event_reqs).to all(have_been_made)
        expect(subscription_req).to have_been_made

        svc.readonly_dataset do |ds|
          expect(ds.all).to have_length(1)
          expect(ds.first).to include(
            encrypted_refresh_token: "rqin-LtdutD-a_S48IKF8A==",
            microsoft_user_id: "456",
          )
        end
      end

      it "responds to `REFRESHED` request by clearing auth info and triggering full sync for user" do
        insert_cal_user_row(refresh_token: "refreshtok", microsoft_user_id: "456")
        force_set_oauth_access_token("456", "accesstok1")

        token_req = stub_request(:post, "https://login.microsoftonline.com/organizations/oauth2/v2.0/token").
          with(body: hash_including("refresh_token" => "refreshtok2")).
          to_return(status: 200, body: {access_token: "acctok2", expires_in: 500}.to_json, headers: json_headers)
        cal_reqs = stub_calendar_requests("acctok2")
        event_reqs = stub_event_requests("acctok2")
        expiration = Time.now + 4300.minutes
        subscription_req = stub_subscription_request(expiration:)

        body = {"refresh_token" => "refreshtok2", "microsoft_user_id" => "456", "type" => "REFRESHED"}
        svc.upsert_webhook_body(body)
        expect(token_req).to have_been_made
        expect(cal_reqs).to all(have_been_made)
        expect(event_reqs).to all(have_been_made)
        expect(subscription_req).to have_been_made
        svc.readonly_dataset do |ds|
          expect(ds.all).to have_length(1)
          expect(ds.first).to include(
            encrypted_refresh_token: "ZGxqnruLo91GgmZtN46r2A==",
            microsoft_user_id: "456",
          )
        end
      end

      it "responds to `RESYNC` request by triggering full syncs for user and clearing calendar delta urls" do
        force_set_oauth_access_token("456", "acctok")
        row = insert_cal_user_row(refresh_token: "refreshtok", microsoft_user_id: "456")

        cal_reqs = stub_calendar_requests("acctok")
        event_reqs = stub_event_requests("acctok")
        expiration = Time.now + 4300.minutes
        subscription_req = stub_subscription_request(expiration:)

        body = {"refresh_token" => "refrok", "microsoft_user_id" => "456", "type" => "RESYNC"}
        svc.upsert_webhook_body(body)
        expect(cal_reqs).to all(have_been_made)
        expect(event_reqs).to all(have_been_made)
        expect(subscription_req).to have_been_made
      end

      it "responds to `UNLINKED` request by deleting all relevant calendar data" do
        insert_cal_user_row(refresh_token: "refreshtok", microsoft_user_id: "456")
        cal_svc.admin_dataset do |cal_ds|
          cal_ds.multi_insert(
            [
              {data: "{}", microsoft_calendar_id: "a", microsoft_user_id: "456"},
              {data: "{}", microsoft_calendar_id: "b", microsoft_user_id: "789"},
            ],
          )
        end
        event_svc.admin_dataset do |event_ds|
          event_ds.multi_insert(
            [
              {data: "{}", microsoft_event_id: "c", microsoft_user_id: "456"},
              {data: "{}", microsoft_event_id: "d", microsoft_user_id: "456"},
            ],
          )
        end

        body = {"refresh_token" => "refrok", "microsoft_user_id" => "456", "type" => "UNLINKED"}
        svc.upsert_webhook_body(body)

        expect(svc.readonly_dataset(&:all)).to be_empty
        expect(cal_svc.readonly_dataset(&:all)).to have_length(1)
        expect(cal_svc.readonly_dataset(&:first)).to include(microsoft_user_id: "789")
        expect(event_svc.readonly_dataset(&:all)).to be_empty
      end

      it "raises error for unknown request type" do
        body = {"refresh_token" => "refrok", "microsoft_user_id" => "456", "type" => "REMIX"}
        expect do
          svc.upsert_webhook_body(body)
        end.to raise_error(RuntimeError, "Unknown MicrosoftCalendarUserV1 request type: REMIX")
      end
    end
  end

  describe "state machine calculation" do
    describe "calculate_create_state_machine" do
      it "sets the encryption secret and prompts for a webhook secret" do
        sm = sint.calculate_create_state_machine
        expect(sm).to have_attributes(
          needs_input: true,
          prompt: "Paste or type your secret here:",
          prompt_is_secret: true,
          post_to_url: end_with("/transition/webhook_secret"),
          complete: false,
          output: match("add support for replicating Outlook Calendar Users").and(match("generate a secret")),
        )
      end

      it "prompts for the client id" do
        sint.webhook_secret = "abc"
        sm = sint.calculate_create_state_machine
        expect(sm).to have_attributes(
          needs_input: true,
          prompt: include("Client ID"),
          prompt_is_secret: true,
          post_to_url: end_with("/transition/backfill_key"),
          complete: false,
          output: include("we will need the Client ID and Client Secret"),
        )
      end

      it "prompts for the client secret" do
        sint.webhook_secret = "abc"
        sint.backfill_key = "def"
        sm = sint.calculate_create_state_machine
        expect(sm).to have_attributes(
          needs_input: true,
          prompt: include("Client Secret"),
          prompt_is_secret: true,
          post_to_url: end_with("/transition/backfill_secret"),
          complete: false,
          output: "",
        )
      end

      it "prints the webhook secret when all set up" do
        sint.webhook_secret = "abc"
        sint.backfill_key = "def"
        sint.backfill_secret = "xyz"
        sm = sint.calculate_create_state_machine
        expect(sm).to have_attributes(
          needs_input: false,
          prompt: "",
          prompt_is_secret: false,
          post_to_url: "",
          complete: true,
          output: match("All set! Here is the endpoint to send requests to").
            and(match(sint.webhook_secret)).
            and(match(sint.replicator.webhook_endpoint)),
        )
      end
    end
  end

  describe "calculate_backfill_state_machine" do
    it "uses the create state machine" do
      sm = sint.calculate_backfill_state_machine
      expect(sm).to have_attributes(
        output: match("You are about to add support for replicating Outlook Calendar Users"),
        needs_input: true,
      )
    end
  end

  describe "subscription management" do
    let(:access_token) { "accesstok" }
    let(:refresh_token) { "refreshtok" }

    before(:each) do
      org.prepare_database_connections
      svc.create_table
    end

    after(:each) do
      org.remove_related_database
    end

    def refreshed(row)
      refresh_row(row, replicator: svc)
    end

    def update(row, **fields)
      update_row(row, replicator: svc, **fields)
    end

    describe "create_or_update_event_change_subscription" do
      let(:user_id) { "456" }
      let(:row) { insert_cal_user_row(refresh_token:, microsoft_user_id: user_id) }

      before(:each) do
        force_set_oauth_access_token(user_id)
      end

      it "creates and stores the subscription" do
        expiration = Time.now + 4300.minutes
        req = stub_subscription_request(expiration:)
        svc.create_or_update_event_change_subscription(svc, row)
        expect(req).to have_been_made
        expect(refreshed(row)).to include(
          events_subscription_expiration: match_time(expiration),
          events_subscription_id: "subscription_id",
        )
      end

      describe "with an existing subscription" do
        let(:old_expiration) { Time.now + 1000.minutes }

        before(:each) do
          update(row, events_subscription_id: "sub_id123", events_subscription_expiration: old_expiration)
        end

        it "renews it" do
          expiration = Time.now + 4300.minutes
          req = stub_subscription_request(subscription_id: "sub_id123", expiration:, method: :patch)
          svc.create_or_update_event_change_subscription(svc, refreshed(row))
          expect(req).to have_been_made
          expect(refreshed(row)).to include(
            events_subscription_expiration: match_time(expiration),
            events_subscription_id: "sub_id123",
          )
        end
      end

      it "raises if the subscription request errors" do
        expiration = Time.now + 4300.minutes
        req = stub_subscription_request(expiration:, status: 400, body: {})
        expect do
          svc.create_or_update_event_change_subscription(svc, row)
        end.to raise_error(Webhookdb::Http::Error)
        expect(req).to have_been_made
      end
    end

    describe "bulk_update_expiring_subscriptiones" do
      let(:before_cutoff) { Time.now + 12.hours }
      let(:after_cutoff) { Time.now + 2.weeks }

      def insert_expiring_row
        return insert_cal_user_row(
          refresh_token:,
          microsoft_user_id: SecureRandom.hex(4),
          events_subscription_id: "sub_id123",
          events_subscription_expiration: before_cutoff,
        )
      end

      def insert_not_expiring_row
        return insert_cal_user_row(
          refresh_token:,
          microsoft_user_id: SecureRandom.hex(4),
          events_subscription_id: "sub_id456",
          events_subscription_expiration: after_cutoff,
        )
      end

      it "selects rows that are expiring soon and sends new subscription request" do
        expir_row = insert_expiring_row
        not_expir_row = insert_not_expiring_row
        user_id = expir_row.fetch(:microsoft_user_id)
        force_set_oauth_access_token(user_id, access_token)

        expiration = Time.now + 4300.minutes
        req = stub_subscription_request(subscription_id: "sub_id123", expiration:, method: :patch)
        svc.bulk_update_expiring_subscriptions
        expect(req).to have_been_made

        expect(refreshed(expir_row)).to include(
          events_subscription_expiration: match_time(expiration),
          events_subscription_id: "sub_id123",
        )
        expect(refreshed(not_expir_row)).to include(
          events_subscription_expiration: match_time(after_cutoff),
          events_subscription_id: "sub_id456",
        )
      end

      it "noops when no rows are expiring soon" do
        not_expir_row = insert_not_expiring_row
        svc.bulk_update_expiring_subscriptions
        expect(refreshed(not_expir_row)).to include(**not_expir_row)
      end
    end
  end

  describe "webhook_response" do
    it "validates using Whdb-Webhook-Secret header" do
      sint.webhook_secret = "goodsecret"
      badreq = fake_request
      badreq.add_header("HTTP_WHDB_WEBHOOK_SECRET", "badsecret")
      expect(svc.webhook_response(badreq)).to have_attributes(status: 401)

      goodreq = fake_request
      goodreq.add_header("HTTP_WHDB_WEBHOOK_SECRET", "goodsecret")
      expect(svc.webhook_response(goodreq)).to have_attributes(status: 202)
    end

    it "returns the validation token string and a 200 when it is present" do
      token = "Validation: Testing client application reachability for subscription Request-Id: ms_sub_id"
      req = fake_request
      req.params["validationToken"] = token
      expect(svc.webhook_response(req)).to have_attributes(
        status: 200,
        headers: {"Content-Type" => "text/plain;charset=utf-8"},
        body: token,
      )
    end

    it "detects when a request looks like it's from Microsoft and validates using `clientState` field" do
      sint.webhook_secret = "goodsecret"
      badreq = fake_request
      badreq.params["value"] = [{"clientState" => "badsecret"}]
      expect(svc.webhook_response(badreq)).to have_attributes(status: 401)

      goodreq = fake_request
      goodreq.params["value"] = [{"clientState" => "goodsecret"}]
      expect(svc.webhook_response(goodreq)).to have_attributes(status: 202)
    end
  end

  describe "with_access_token" do
    before(:each) do
      org.prepare_database_connections
      svc.create_table
    end

    after(:each) do
      org.remove_related_database
    end

    it "raises for no row" do
      expect do
        svc.with_access_token("xyz") {}
      end.to raise_error(Webhookdb::InvalidPrecondition)
    end

    it "requests an access token using the refresh token" do
      sint.update(backfill_key: "bkey", backfill_secret: "bsec")
      req = stub_request(:post, "https://login.microsoftonline.com/organizations/oauth2/v2.0/token").
        with(
          body: hash_including(
            "client_id" => "bkey",
            "client_secret" => "bsec",
            "refresh_token" => "rtok",
            "grant_type" => "refresh_token",
          ),
        ).to_return(status: 200, body: {access_token: "sometok", expires_in: 600}.to_json, headers: json_headers)
      insert_cal_user_row(microsoft_user_id: "extid", refresh_token: "rtok")
      svc.with_access_token("extid") do |tok|
        expect(tok).to eq("sometok")
      end
      svc.with_access_token("extid") do |tok|
        expect(tok).to eq("sometok")
      end
      expect(req).to have_been_made.times(1)
    end

    it "uses a stored token when available" do
      insert_cal_user_row(microsoft_user_id: "extid")
      svc.force_set_oauth_access_token("extid", "sometok")
      svc.with_access_token("extid") do |tok|
        expect(tok).to eq("sometok")
      end
    end
  end
end
