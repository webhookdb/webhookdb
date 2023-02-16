# frozen_string_literal: true

require "support/shared_examples_for_replicators"

RSpec.describe Webhookdb::Replicator::MicrosoftCalendarEventV1, :db do
  let(:org) { Webhookdb::Fixtures.organization.create }
  let(:fac) { Webhookdb::Fixtures.service_integration(organization: org) }
  let(:calendar_user_sint) { fac.stable_encryption_secret.create(service_name: "microsoft_calendar_user_v1") }
  let(:calendar_user_svc) { calendar_user_sint.replicator }
  let(:calendar_sint) { fac.depending_on(calendar_user_sint).create(service_name: "microsoft_calendar_v1").refresh }
  let(:calendar_svc) { calendar_sint.replicator }
  let(:sint) { fac.depending_on(calendar_sint).create(service_name: "microsoft_calendar_event_v1") }
  let(:svc) { sint.replicator }
  let(:access_token) { "acctok" }
  let(:encrypted_refresh_token) { "WxQFR-78if2_60yEY3RgrA==" }
  let(:microsoft_user_id) { "123" }
  let(:microsoft_calendar_id) { "cal1" }

  let(:created) { Time.new(2023, 1, 1) }
  let(:updated) { Time.new(2023, 1, 2) }
  let(:start_time) { Time.new(2023, 2, 22) }
  let(:end_time) { Time.new(2023, 2, 23) }

  let(:calview_start_enc) { ERB::Util.url_encode(Webhookdb::MicrosoftCalendar.calendar_view_start_time.iso8601) }
  let(:calview_end_enc) { ERB::Util.url_encode(Webhookdb::MicrosoftCalendar.calendar_view_end_time.iso8601) }
  let(:calview_query_start_end) { "endDateTime=#{calview_end_enc}&startDateTime=#{calview_start_enc}" }

  let(:body) do
    # Although "microsoft_user_id" and "microsoft_calendar_id" are not part of the actual data
    # we get from the API, we always add it in the `handle_item` function of the backfiller. We aren't
    # upserting data any other way, therefore it makes sense to just add the fields to the sample API data.
    JSON.parse(<<~J)
      {
        "microsoft_user_id": "123",
        "microsoft_calendar_id": "cal1",
        "id": "ev1",
        "end": {
            "dateTime": "#{end_time.iso8601}",
            "timeZone": "UTC"
          },
          "body": {
            "content": "",
            "contentType": "html"
          },
          "type": "singleInstance",
          "start": {
            "dateTime": "#{start_time.iso8601}",
            "timeZone": "UTC"
          },
          "showAs": "busy",
          "iCalUId": "040000008200E00074C5B7101A82E008000000009ED0828DCC3CD90100000000000000001000000047E36FF71EC50246A6E6C2DE2E184BA8",
          "isDraft": false,
          "subject": "sgkldzjfdskl",
          "webLink": "https://outlook.office365.com/owa/?itemid=AAMkAGEwYTU1YWIzLTM3YmYtNDVlOS04MjY2LWY5NTM5ZTNjNmViYgBGAAAAAAAtNIgM9rYtQLAL2azCIjXGBwCAprvuOhxrSan16p%2FlvvGYAAAAAAENAACAprvuOhxrSan16p%2FlvvGYAAADlUstAAA%3D&exvsurl=1&path=/calendar/item",
          "isAllDay": false,
          "location": {
            "address": {},
            "coordinates": {},
            "displayName": "",
            "locationType": "default",
            "uniqueIdType": "unknown"
          },
          "attendees": [],
          "changeKey": "gKa77joca0mp9eqf5b7xmAAAA5LNrg==",
          "locations": [],
          "organizer": {
            "emailAddress": {
              "name": "Natalie  Edson",
              "address": "natalie@natalielithic.onmicrosoft.com"
            }
          },
          "categories": [],
          "importance": "normal",
          "recurrence": null,
          "bodyPreview": "",
          "isCancelled": false,
          "isOrganizer": true,
          "sensitivity": "normal",
          "isReminderOn": true,
          "occurrenceId": null,
          "hideAttendees": false,
          "onlineMeeting": null,
          "transactionId": "315e8e29-2ef2-a831-8b91-bfd0072768d1",
          "hasAttachments": false,
          "responseStatus": {
            "time": "0001-01-01T00:00:00Z",
            "response": "organizer"
          },
          "seriesMasterId": null,
          "createdDateTime": "#{created.iso8601}",
          "isOnlineMeeting": false,
          "onlineMeetingUrl": null,
          "responseRequested": true,
          "originalEndTimeZone": "Pacific Standard Time",
          "lastModifiedDateTime": "#{updated.iso8601}",
          "allowNewTimeProposals": true,
          "onlineMeetingProvider": "unknown",
          "originalStartTimeZone": "Pacific Standard Time",
          "reminderMinutesBeforeStart": 15
      }
    J
  end
  let(:expected_insert) do
    remote_only_body = body.dup
    remote_only_body.delete("microsoft_user_id")
    remote_only_body.delete("microsoft_calendar_id")
    return {
      data: Sequel::Postgres::JSONBHash.new(remote_only_body),
      microsoft_user_id: "123",
      microsoft_calendar_id: "cal1",
      microsoft_event_id: "ev1",
      row_created_at: match_time(:now),
      row_updated_at: match_time(:now),
      created:,
      updated:,
      is_all_day: false,
      start_at: start_time,
      start_timezone: "UTC",
      original_start_timezone: "Pacific Standard Time",
      end_at: end_time,
      end_timezone: "UTC",
      original_end_timezone: "Pacific Standard Time",
    }
  end

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

  def insert_calendar_row(**more)
    calendar_svc.admin_dataset do |ds|
      ds.insert(
        data: "{}",
        microsoft_user_id:,
        microsoft_calendar_id:,
        is_default_calendar: false,
        **more,
      )
      return ds.order(:pk).last
    end
  end

  def force_set_oauth_access_token(extownerid=microsoft_user_id, atok=access_token)
    calendar_user_svc.force_set_oauth_access_token(extownerid, atok)
  end

  it_behaves_like "a replicator", "microsoft_calendar_event_v1" do
    let(:body) { super() }

    let(:expected_row) { include(:pk, **expected_insert) }
    let(:supports_row_diff) { false }
  end

  it_behaves_like "a replicator dependent on another", "microsoft_calendar_event_v1", "microsoft_calendar_v1" do
    let(:no_dependencies_message) { "" }
  end

  describe "sync behavior" do
    before(:each) do
      org.prepare_database_connections
      calendar_user_svc.create_table
      calendar_svc.create_table
      svc.create_table
      Webhookdb::MicrosoftCalendar.list_page_size = 1
    end

    after(:each) do
      org.remove_related_database
    end

    let(:page1_response) { {"value" => [{"id" => "cal1"}]} }
    let(:page2_response) { {"value" => [{"id" => "cal2"}]} }

    let(:calendar_row) { insert_calendar_row }

    let(:delta_url) { "https://graph.microsoft.com/v1.0/me/calendarView/delta?%24deltatoken=bar200&endDateTime=2027-09-30T00%3A00%3A00%3A07%3A00&startDateTime=2022-10-01T00%3A00%3A00-07%3A00" }
    let(:delta_url_page_response) { page2_response.merge({"@odata.deltaLink" => delta_url}) }

    describe "EventBackfiller" do
      let(:backfiller) do
        Webhookdb::Replicator::MicrosoftCalendarEventV1::EventBackfiller.new(
          event_svc: svc,
          access_token:,
          calendar_row:,
        )
      end

      before(:each) do
        force_set_oauth_access_token
      end

      it "syncs all events" do
        sync_req = stub_request(:get, "https://graph.microsoft.com/v1.0/me/calendars/cal1/calendarView?%24top=1&#{calview_query_start_end}").
          with(
            headers: {"Authorization" => "Bearer acctok"},
          ).to_return(json_response(page1_response))
        backfiller.run_backfill
        expect(sync_req).to have_been_made
      end

      it "errors if the sync fails multiple times" do
        req410 = stub_request(:get, "https://graph.microsoft.com/v1.0/me/calendars/cal1/calendarView?%24top=1&#{calview_query_start_end}").
          with(
            headers: {"Authorization" => "Bearer acctok"},
          ).to_return(json_response({}, status: 410))
        expect(Webhookdb::Backfiller).to receive(:do_retry_wait).at_least(:once)
        expect do
          backfiller.run_backfill
        end.to raise_error(Webhookdb::Http::Error)
        expect(req410).to have_been_made.times(3)
      end

      it "uses the 'next link' value as a pagination token until it is no longer returned" do
        insert_calendar_user_row
        sync_reqs = [
          stub_request(:get, "https://graph.microsoft.com/v1.0/me/calendars/cal1/calendarView?%24top=1&#{calview_query_start_end}").
            with(
              headers: {"Authorization" => "Bearer acctok"},
            ).to_return(json_response(page1_response.merge({"@odata.nextLink" => "https://graph.microsoft.com/v1.0/me/calendars/cal1/calendarView?%24skip=1&%24top=1&#{calview_query_start_end}"}))),
          stub_request(:get, "https://graph.microsoft.com/v1.0/me/calendars/cal1/calendarView?%24skip=1&%24top=1&#{calview_query_start_end}").
            with(
              headers: {"Authorization" => "Bearer acctok"},
            ).to_return(json_response(page2_response)),
        ]
        backfiller.run_backfill
        expect(sync_reqs).to all(have_been_made)
      end

      it "upserts incoming data with the microsoft_user_id and microsoft_calendar_id from the parent" do
        sync_req = stub_request(:get, "https://graph.microsoft.com/v1.0/me/calendars/cal1/calendarView?%24top=1&#{calview_query_start_end}").
          with(
            headers: {"Authorization" => "Bearer acctok"},
          ).to_return(json_response(page2_response))
        backfiller.run_backfill
        expect(sync_req).to have_been_made
        svc.readonly_dataset do |ds|
          expect(ds.first).to include(microsoft_user_id: "123", microsoft_calendar_id: "cal1")
        end
      end
    end

    describe "EventDeltaBackfiller" do
      let(:backfiller) do
        Webhookdb::Replicator::MicrosoftCalendarEventV1::EventDeltaBackfiller.new(
          event_svc: svc,
          access_token:,
          calendar_row:,
          calendar_svc:,
        )
      end

      before(:each) do
        force_set_oauth_access_token
      end

      it "syncs all events" do
        sync_req = stub_request(:get, "https://graph.microsoft.com/v1.0/me/calendarView/delta?#{calview_query_start_end}").
          with(headers: {"Authorization" => "Bearer acctok"}).
          to_return(json_response(delta_url_page_response))
        backfiller.run_backfill
        expect(sync_req).to have_been_made
      end

      it "errors if the sync fails multiple times" do
        req410 = stub_request(:get, "https://graph.microsoft.com/v1.0/me/calendarView/delta?#{calview_query_start_end}").
          with(headers: {"Authorization" => "Bearer acctok"}).
          to_return(json_response({}, status: 410))
        expect(Webhookdb::Backfiller).to receive(:do_retry_wait).at_least(:once)
        expect do
          backfiller.run_backfill
        end.to raise_error(Webhookdb::Http::Error)
        expect(req410).to have_been_made.times(3)
      end

      it "uses the 'next link' value as a pagination token until it is no longer returned" do
        insert_calendar_user_row
        sync_reqs = [
          stub_request(:get, "https://graph.microsoft.com/v1.0/me/calendarView/delta?#{calview_query_start_end}").
            with(headers: {"Authorization" => "Bearer acctok"}).
            to_return(json_response(page1_response.merge({"@odata.nextLink" => "https://graph.microsoft.com/v1.0/me/calendarView/delta?%24skiptoken=foo100&#{calview_query_start_end}"}))),
          stub_request(:get, "https://graph.microsoft.com/v1.0/me/calendarView/delta?$skiptoken=foo100&#{calview_query_start_end}").
            with(headers: {"Authorization" => "Bearer acctok"}).
            to_return(json_response(delta_url_page_response)),
        ]
        backfiller.run_backfill
        expect(sync_reqs).to all(have_been_made)
      end

      it "upserts incoming data with the microsoft_user_id and microsoft_calendar_id from the parent" do
        sync_req = stub_request(:get, "https://graph.microsoft.com/v1.0/me/calendarView/delta?#{calview_query_start_end}").
          with(headers: {"Authorization" => "Bearer acctok"}).
          to_return(json_response(delta_url_page_response))
        backfiller.run_backfill
        expect(sync_req).to have_been_made
        svc.readonly_dataset do |ds|
          expect(ds.first).to include(microsoft_user_id: "123", microsoft_calendar_id: "cal1")
        end
      end

      it "updates the delta url on the parent calendar row" do
        sync_req = stub_request(:get, "https://graph.microsoft.com/v1.0/me/calendarView/delta?#{calview_query_start_end}").
          with(headers: {"Authorization" => "Bearer acctok"}).
          to_return(json_response(delta_url_page_response))
        backfiller.run_backfill
        expect(sync_req).to have_been_made
        calendar_svc.readonly_dataset do |cal_ds|
          expect(cal_ds[microsoft_calendar_id: "cal1"]).to include(delta_url:)
        end
      end

      it "uses the delta from the parent calendar row if present" do
        calendar_row.update(delta_url: "https://graph.microsoft.com/v1.0/me/calendarView/delta?%24deltatoken=baz300&#{calview_query_start_end}")
        # make backfiller with updated calendar row
        backfiller = Webhookdb::Replicator::MicrosoftCalendarEventV1::EventDeltaBackfiller.new(
          event_svc: svc,
          access_token:,
          calendar_row:,
          calendar_svc:,
        )
        sync_req = stub_request(:get, "https://graph.microsoft.com/v1.0/me/calendarView/delta?$deltatoken=baz300&#{calview_query_start_end}").
          with(headers: {"Authorization" => "Bearer acctok"}).
          to_return(json_response(delta_url_page_response))
        backfiller.run_backfill
        expect(sync_req).to have_been_made
      end
    end

    describe "sync_calendar_events" do
      it "uses EventDeltaBackfiller if calendar is default" do
        default_cal = insert_calendar_row(is_default_calendar: true)
        sync_req = stub_request(:get, "https://graph.microsoft.com/v1.0/me/calendarView/delta?#{calview_query_start_end}").
          with(headers: {"Authorization" => "Bearer acctok"}).
          to_return(json_response(delta_url_page_response))
        svc.sync_calendar_events(calendar_svc, default_cal, access_token)
        expect(sync_req).to have_been_made
      end

      it "uses EventBackfiller if calendar is not default" do
        sync_req = stub_request(:get, "https://graph.microsoft.com/v1.0/me/calendars/cal1/calendarView?%24top=1&#{calview_query_start_end}").
          with(
            headers: {"Authorization" => "Bearer acctok"},
          ).to_return(json_response(page1_response))
        svc.sync_calendar_events(calendar_svc, calendar_row, access_token)
        expect(sync_req).to have_been_made
      end
    end
  end

  describe "state machine calculation" do
    describe "calculate_create_state_machine" do
      it "prompts for dependencies" do
        sint.update(depends_on: nil)
        calendar_sint.destroy
        calendar_user_sint.destroy
        sm = sint.calculate_create_state_machine
        expect(sm).to have_attributes(output: /You don't have any Outlook Calendar integrations yet/)
      end

      it "returns a generic message" do
        sm = sint.calculate_create_state_machine
        expect(sm).to have_attributes(
          output: match("Great! You are all set."),
          complete: true,
          needs_input: false,
        )
      end
    end

    describe "calculate_backfill_state_machine" do
      it "errors as not available" do
        sm = sint.calculate_backfill_state_machine
        expect(sm).to have_attributes(
          output: match("Outlook Calendar Event does not support backfilling"),
          complete: true,
          needs_input: false,
        )
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
  end
end
