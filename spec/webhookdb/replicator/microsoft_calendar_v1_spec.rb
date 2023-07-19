# frozen_string_literal: true

require "support/shared_examples_for_replicators"

RSpec.describe Webhookdb::Replicator::MicrosoftCalendarV1, :db do
  let(:org) { Webhookdb::Fixtures.organization.create }
  let(:fac) { Webhookdb::Fixtures.service_integration(organization: org) }
  let(:calendar_user_sint) { fac.stable_encryption_secret.create(service_name: "microsoft_calendar_user_v1") }
  let(:calendar_user_svc) { calendar_user_sint.replicator }
  let(:sint) { fac.depending_on(calendar_user_sint).create(service_name: "microsoft_calendar_v1").refresh }
  let(:svc) { sint.replicator }
  let(:event_sint) { fac.depending_on(sint).create(service_name: "microsoft_calendar_event_v1") }
  let(:event_svc) { event_sint.replicator }
  let(:access_token) { "acctok" }
  let(:encrypted_refresh_token) { "WxQFR-78if2_60yEY3RgrA==" }
  let(:microsoft_user_id) { "123" }

  def insert_calendar_user_row(**more)
    calendar_user_svc.admin_dataset do |ds|
      ds.insert(
        data: "{}",
        encrypted_refresh_token:,
        microsoft_user_id:,
        **more,
      )
      return ds.order(:pk).last
    end
  end

  def force_set_oauth_access_token(ms_user_id=microsoft_user_id, atok=access_token)
    calendar_user_svc.force_set_oauth_access_token(ms_user_id, atok)
  end

  it_behaves_like "a replicator", "microsoft_calendar_v1" do
    let(:body) do
      # Although "microsoft_user_id" is not part of the actual data we get from the API,
      # we always add it in the `handle_item` function of the backfiller. We aren't upserting
      # data any other way, therefore it makes sense to just add the field to the sample API data.
      JSON.parse(<<~J)
        {
          "microsoft_user_id": "123",
          "id": "cal1",
          "name": "Calendar",
          "color": "auto",
          "owner": {"name": "Natalie  Edson", "address": "natalie@example.com"},
          "canEdit": true,
          "canShare": true,
          "hexColor": "",
          "changeKey": "gKa77joca0mp9eqf5b7xmAAAAAACYg==",
          "isRemovable": false,
          "isDefaultCalendar": true,
          "canViewPrivateItems": true,
          "isTallyingResponses": true,
          "defaultOnlineMeetingProvider": "teamsForBusiness",
          "allowedOnlineMeetingProviders": ["teamsForBusiness"]
        }
      J
    end
    let(:expected_row) do
      remote_only_body = body.dup
      remote_only_body.delete("microsoft_user_id")
      include(
        :pk,
        data: Sequel::Postgres::JSONBHash.new(remote_only_body),
        microsoft_user_id: "123",
        microsoft_calendar_id: "cal1",
        row_created_at: match_time(:now),
        row_updated_at: match_time(:now),
      )
    end
    let(:supports_row_diff) { false }
  end

  it_behaves_like "a replicator dependent on another", "microsoft_calendar_v1", "microsoft_calendar_user_v1" do
    let(:no_dependencies_message) { "" }
  end

  describe "upsert behavior" do
    let(:body) do
      JSON.parse(<<~J)
        {
          "microsoft_user_id": "123",
          "id": "cal1",
          "isDefaultCalendar": false
        }
      J
    end

    before(:each) do
      org.prepare_database_connections
      calendar_user_svc.create_table
      svc.create_table
    end

    after(:each) do
      org.remove_related_database
    end

    it "does not stomp created_at but does stomp updated_at" do
      svc.upsert_webhook_body(body)

      row1 = svc.readonly_dataset(&:first)
      expect(row1[:row_updated_at]).to match_time(:now)
      updated = 1.hour.from_now
      Timecop.travel(updated) do
        svc.upsert_webhook_body(body)
      end
      row2 = svc.readonly_dataset(&:first)

      expect(row2[:row_created_at]).to match_time(row1[:row_created_at])
      expect(row2[:row_updated_at]).to match_time(updated)
    end
  end

  describe "sync behavior" do
    before(:each) do
      org.prepare_database_connections
      calendar_user_svc.create_table
      svc.create_table
      Webhookdb::MicrosoftCalendar.list_page_size = 1
    end

    after(:each) do
      org.remove_related_database
    end

    let(:page1_response) do
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
         "isDefaultCalendar" => true,
         "canViewPrivateItems" => true,
         "isTallyingResponses" => true,
         "defaultOnlineMeetingProvider" => "teamsForBusiness",
         "allowedOnlineMeetingProviders" => ["teamsForBusiness"],},
      ]}
    end

    let(:page2_response) do
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

    def stub_service_request(body, params: {}, status: 200)
      url = "https://graph.microsoft.com/v1.0/me/calendars?%24top=1&" + URI.encode_www_form(params)
      return stub_request(:get, url).with(headers: {"Authorization" => "Bearer acctok"}).
          to_return(status:, body: body.to_json, headers: {"Content-Type" => "application/json"})
    end

    describe "sync_calendar_user_calendars" do
      it "syncs all calendars" do
        calendar_user_row = insert_calendar_user_row
        force_set_oauth_access_token
        sync_req = stub_service_request(page1_response)
        svc.sync_calendar_user_calendars(calendar_user_row, access_token)
        expect(sync_req).to have_been_made
      end

      it "errors if the sync fails multiple times" do
        calendar_user_row = insert_calendar_user_row
        force_set_oauth_access_token
        req410 = stub_service_request({}, status: 410)
        expect(Webhookdb::Backfiller).to receive(:do_retry_wait).at_least(:once)
        expect do
          svc.sync_calendar_user_calendars(calendar_user_row, access_token)
        end.to raise_error(Webhookdb::Http::Error)
        expect(req410).to have_been_made.times(3)
      end

      it "uses the 'next link' value as a pagination token until it is no longer returned" do
        calendar_user_row = insert_calendar_user_row
        force_set_oauth_access_token
        sync_reqs = [
          stub_service_request(page1_response.merge({"@odata.nextLink" => "https://graph.microsoft.com/v1.0/me/calendars?%24top=1&%24skip=1"})),
          stub_service_request(page2_response, params: {"$skip" => 1}),
        ]
        svc.sync_calendar_user_calendars(calendar_user_row, access_token)
        expect(sync_reqs).to all(have_been_made)
      end

      it "upserts incoming data with the microsoft_user_id from the parent" do
        calendar_user_row = insert_calendar_user_row
        force_set_oauth_access_token
        sync_req = stub_service_request(page2_response)
        svc.sync_calendar_user_calendars(calendar_user_row, access_token)
        expect(sync_req).to have_been_made
        svc.readonly_dataset do |ds|
          expect(ds.first).to include(microsoft_user_id: "123", microsoft_calendar_id: "cal2")
        end
      end
    end
  end

  describe "state machine calculation" do
    describe "calculate_webhook_state_machine" do
      it "prompts for dependencies" do
        sint.update(depends_on: nil)
        calendar_user_sint.destroy
        sm = sint.replicator.calculate_webhook_state_machine
        expect(sm).to have_attributes(output: /You don't have any Outlook Calendar User integrations yet/)
      end

      it "returns a generic message" do
        sm = sint.replicator.calculate_webhook_state_machine
        expect(sm).to have_attributes(
          output: match("Great! You are all set."),
          complete: true,
          needs_input: false,
        )
      end
    end
  end

  it_behaves_like "a replicator with a custom backfill not supported message", "microsoft_calendar_v1"

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
  end
end
