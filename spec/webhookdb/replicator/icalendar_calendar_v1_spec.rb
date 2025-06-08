# frozen_string_literal: true

require "support/shared_examples_for_replicators"

# rubocop:disable Layout/LineLength
RSpec.describe Webhookdb::Replicator::IcalendarCalendarV1, :db do
  let(:org) { Webhookdb::Fixtures.organization.create }
  let(:fac) { Webhookdb::Fixtures.service_integration(organization: org) }
  let(:sint) { fac.stable_encryption_secret.create(service_name: "icalendar_calendar_v1") }
  let(:svc) { sint.replicator }
  let(:event_sint) { fac.depending_on(sint).create(service_name: "icalendar_event_v1") }
  let(:event_svc) { event_sint.replicator }

  def insert_calendar_row(**more)
    svc.admin_dataset do |ds|
      inserted = ds.returning(Sequel.lit("*")).
        insert(
          data: "{}",
          row_created_at: Time.now,
          row_updated_at: Time.now,
          **more,
        )
      return inserted.first
    end
  end

  it_behaves_like "a replicator", supports_row_diff: false do
    let(:sint) { super() }
    let(:body) do
      JSON.parse(<<~J)
        {
          "type": "__WHDB_UNIT_TEST",
          "external_id": "123",
          "ics_url": "https://foo.bar/basic.ics"
        }
      J
    end
    let(:expected_row) do
      include(
        :pk,
        data: {},
        ics_url: "https://foo.bar/basic.ics",
        external_id: "123",
        row_created_at: match_time(:now),
        row_updated_at: match_time(:now),
        last_synced_at: nil,
      )
    end
  end

  it_behaves_like "a replicator with dependents", "icalendar_event_v1" do
    let(:sint) { super() }
    let(:body) do
      JSON.parse(<<~J)
        {
          "type": "__WHDB_UNIT_TEST",
          "external_id": "123",
          "ics_url": "https://foo"
        }
      J
    end
    let(:can_track_row_changes) { false }
    let(:expected_insert) do
      {
        data: "{}",
        external_id: "123",
        ics_url: "https://foo",
        last_synced_at: nil,
        row_created_at: match_time(:now),
        row_updated_at: match_time(:now),
        event_count: nil,
        feed_bytes: nil,
        last_sync_duration_ms: nil,
        last_fetch_context: nil,
      }
    end
  end

  describe "upsert behavior" do
    describe "upsert_webhook" do
      let(:base_request) do
        {
          "external_id" => "456",
          "ics_url" => "https://foo.bar/basic.ics",
        }
      end

      before(:each) do
        org.prepare_database_connections
        svc.create_table
      end

      after(:each) do
        org.remove_related_database
      end

      it "responds to `SYNC` requests by upserting and enqueing a sync", sidekiq: :fake do
        body = {"ics_url" => "https://abc.url", "external_id" => "456", "type" => "SYNC"}
        svc.upsert_webhook_body(body)

        svc.readonly_dataset do |ds|
          expect(ds.all).to contain_exactly(
            include(
              ics_url: "https://abc.url",
              external_id: "456",
            ),
          )
        end
        expect(Sidekiq).to have_queue("netout").consisting_of(
          job_hash(Webhookdb::Jobs::IcalendarSync, args: [sint.id, "456"]),
        )
      end

      it "selectively stomps fields" do
        body = {"type" => "__WHDB_UNIT_TEST", "external_id" => "123", "ics_url" => "https://a.b"}
        svc.upsert_webhook_body(body)

        row1 = svc.readonly_dataset(&:first)
        expect(row1[:row_updated_at]).to match_time(:now)
        updated = 1.hour.from_now
        Timecop.travel(updated) do
          svc.upsert_webhook_body(body.merge("ics_url" => "https://y.z"))
        end
        expect(svc.readonly_dataset(&:all)).to contain_exactly(
          include(
            external_id: "123",
            row_created_at: match_time(row1[:row_created_at]),
            row_updated_at: match_time(updated).within(1.second),
            ics_url: "https://y.z",
          ),
        )
      end

      it "replaces webcal protocol with https", sidekiq: :fake do
        body = {"ics_url" => "webcal://abc.url", "external_id" => "456", "type" => "SYNC"}
        svc.upsert_webhook_body(body)

        svc.readonly_dataset do |ds|
          expect(ds.all).to contain_exactly(
            include(
              ics_url: "https://abc.url",
              external_id: "456",
            ),
          )
        end
        expect(Sidekiq).to have_queue("netout").consisting_of(
          job_hash(Webhookdb::Jobs::IcalendarSync, args: [sint.id, "456"]),
        )
      end

      it "responds to `DELETE` request by deleting all relevant calendar data" do
        event_svc.create_table

        insert_calendar_row(ics_url: "https://x.y", external_id: "456")
        insert_calendar_row(ics_url: "https://x.y", external_id: "567")
        event_svc.admin_dataset do |event_ds|
          event_ds.multi_insert(
            [
              {data: "{}", uid: "c", calendar_external_id: "456", compound_identity: "456-c"},
              {data: "{}", uid: "d", calendar_external_id: "567", compound_identity: "567-d"},
            ],
          )
        end

        body = {"external_id" => "456", "type" => "DELETE"}
        svc.upsert_webhook_body(body)

        expect(svc.readonly_dataset(&:all)).to contain_exactly(include(external_id: "567"))
        expect(event_svc.readonly_dataset(&:all)).to contain_exactly(include(uid: "d"))
      end

      it "raises error for unknown request type" do
        body = {"refresh_token" => "refrok", "external_id" => "456", "type" => "REMIX"}
        expect do
          svc.upsert_webhook_body(body)
        end.to raise_error(ArgumentError, "Unknown request type: REMIX")
      end
    end
  end

  describe "state machine calculation" do
    describe "calculate_webhook_state_machine" do
      it "prompts for the secret" do
        sm = sint.replicator.calculate_webhook_state_machine
        expect(sm).to have_attributes(
          needs_input: true,
          complete: false,
          output: include("about to add support for replicating iCalendar"),
          prompt: include("secret"),
        )
      end

      it "completes if secret is set" do
        sint.webhook_secret = "abc"
        sm = sint.replicator.calculate_webhook_state_machine
        expect(sm).to have_attributes(
          needs_input: false,
          complete: true,
          output: include("All set! Here is the endpoint"),
        )
      end
    end
  end

  it_behaves_like "a replicator with a custom backfill not supported message"

  describe "webhook_response" do
    it "validates using Whdb-Webhook-Secret" do
      sint.webhook_secret = "goodsecret"
      badreq = fake_request
      badreq.add_header("HTTP_WHDB_WEBHOOK_SECRET", "badsecret")
      expect(svc.webhook_response(badreq)).to have_attributes(status: 401)

      goodreq = fake_request
      goodreq.add_header("HTTP_WHDB_WEBHOOK_SECRET", "goodsecret")
      expect(svc.webhook_response(goodreq)).to have_attributes(status: 202)
    end
  end

  describe "rows_needing_sync" do
    before(:each) do
      org.prepare_database_connections
      svc.create_table
    end

    after(:each) do
      org.remove_related_database
    end

    it "selects rows that have not been synced in 4 hours" do
      sync1 = insert_calendar_row(ics_url: "https://x.y", external_id: "abc")
      sync2 = insert_calendar_row(ics_url: "https://x.y", external_id: "def", last_synced_at: 12.hours.ago)
      nosync = insert_calendar_row(ics_url: "https://x.y", external_id: "xyz", last_synced_at: 1.hour.ago)

      rows = svc.admin_dataset { |ds| svc.rows_needing_sync(ds).all }
      expect(rows).to contain_exactly(include(pk: sync1[:pk]), include(pk: sync2[:pk]))
    end
  end

  describe "sync_row" do
    before(:each) do
      org.prepare_database_connections
      svc.create_table
      event_svc.create_table
    end

    after(:each) do
      org.remove_related_database
    end

    it "upserts each vevent in the url, and stores meta about the fetch" do
      literal = '\n\r\n\t\n'
      body = <<~ICAL
        BEGIN:VCALENDAR
        VERSION:2.0
        PRODID:-//ZContent.net//Zap Calendar 1.0//EN
        CALSCALE:GREGORIAN
        METHOD:PUBLISH
        BEGIN:VEVENT
        SUMMARY:Abraham Lincoln
        UID:c7614cff-3549-4a00-9152-d25cc1fe077d
        SEQUENCE:0
        STATUS:CONFIRMED
        TRANSP:TRANSPARENT
        DTSTART:20080212
        DTEND:20080213
        DTSTAMP:20150421T141403
        CATEGORIES:U.S. Presidents,Civil War People
        LOCATION:Hodgenville, Kentucky
        GEO:37.5739497;-85.7399606
        DESCRIPTION:Born February 12, 1809\\nSixteenth President (1861-1865)#{literal}
         \\nhttp://AmericanHistoryCalendar.com
        URL:http://americanhistorycalendar.com/peoplecalendar/1,328-abraham-lincol
         n
        END:VEVENT
        END:VCALENDAR
      ICAL
      req = stub_request(:get, "https://feed.me").
        and_return(
          status: 200,
          headers: {
            "Content-Type" => "text/calendar",
            "Content-Length" => body.size.to_s,
            "Etag" => "somevalue",
          },
          body:,
        )
      row = insert_calendar_row(ics_url: "https://feed.me", external_id: "abc")
      svc.sync_row(row)
      expect(req).to have_been_made
      expect(svc.admin_dataset(&:first)).to include(
        last_synced_at: match_time(:now),
        last_sync_duration_ms: be_positive,
        last_fetch_context: {
          "content_length" => body.size.to_s,
          "content_type" => "text/calendar",
          "hash" => "b816a713f55ce89a441a16a72367f5ca",
          "etag" => "somevalue",
        },
      )
      expect(event_svc.admin_dataset(&:all)).to contain_exactly(
        include(
          calendar_external_id: "abc",
          categories: ["U.S. Presidents", "Civil War People"],
          classification: nil,
          compound_identity: "abc-c7614cff-3549-4a00-9152-d25cc1fe077d",
          created_at: nil,
          data: hash_including(
            "DTEND" => {"v" => "20080213"},
            "DESCRIPTION" => {"v" => "Born February 12, 1809\nSixteenth President (1861-1865)\n\r\n\t\n\nhttp://AmericanHistoryCalendar.com"},
            "URL" => {"v" => "http://americanhistorycalendar.com/peoplecalendar/1,328-abraham-lincoln"},
          ),
          end_at: nil,
          end_date: Date.parse("Wed, 13 Feb 2008"),
          geo_lat: 37.5739497,
          geo_lng: -85.7399606,
          last_modified_at: match_time(:now),
          priority: nil,
          row_updated_at: match_time(:now),
          start_at: nil,
          start_date: Date.parse("Tue, 12 Feb 2008"),
          status: "CONFIRMED",
          uid: "c7614cff-3549-4a00-9152-d25cc1fe077d",
        ),
      )
    end

    it "stores the total number of upserts and the feed byte size" do
      body = <<~ICAL
        BEGIN:VCALENDAR
        VERSION:2.0
        PRODID:-//ZContent.net//Zap Calendar 1.0//EN
        CALSCALE:GREGORIAN
        METHOD:PUBLISH
        BEGIN:VEVENT
        SUMMARY:Abraham Lincoln
        UID:c7614cff-3549-4a00-9152-d25cc1fe077d
        SEQUENCE:0
        STATUS:CONFIRMED
        TRANSP:TRANSPARENT
        DTSTART:20080212
        DTEND:20080213
        DTSTAMP:20150421T141403
        RRULE:FREQ=YEARLY;UNTIL=20110101T000000Z
        END:VEVENT
        END:VCALENDAR
      ICAL
      req = stub_request(:get, "https://feed.me").
        and_return(status: 200, headers: {"Content-Type" => "text/calendar"}, body:)
      row = insert_calendar_row(ics_url: "https://feed.me", external_id: "abc")
      svc.sync_row(row)
      expect(req).to have_been_made
      expect(svc.admin_dataset(&:first)).to include(
        last_synced_at: match_time(:now),
        event_count: 3,
        feed_bytes: 354,
      )
      expect(event_svc.admin_dataset(&:all)).to have_length(3)
    end

    it "noops if there's no event integration" do
      event_sint.destroy
      row = insert_calendar_row(ics_url: "https://feed.me", external_id: "abc")
      svc.sync_row(row)
      expect(svc.admin_dataset(&:first)).to include(last_synced_at: match_time(:now))
    end

    it "noops if the server 304s" do
      req = stub_request(:get, "https://feed.me").
        and_return(status: 304)
      row = insert_calendar_row(ics_url: "https://feed.me", external_id: "abc")
      svc.sync_row(row)
      expect(req).to have_been_made
      expect(svc.admin_dataset(&:first)).to include(last_synced_at: match_time(:now))
    end

    it "skips rows that have not been modified" do
      v1 = <<~ICAL
        BEGIN:VCALENDAR
        VERSION:2.0
        PRODID:-//ZContent.net//Zap Calendar 1.0//EN
        CALSCALE:GREGORIAN
        BEGIN:VEVENT
        SUMMARY:Version1
        UID:c7614cff-3549-4a00-9152-d25cc1fe077d
        DTSTART:20080212
        DTEND:20080213
        END:VEVENT
        END:VCALENDAR
      ICAL
      updated1 = v1.gsub("Version1", "Version2")
      req = stub_request(:get, "https://feed.me").
        and_return(
          {status: 200, headers: {"Content-Type" => "text/calendar"}, body: v1},
          {status: 200, headers: {"Content-Type" => "text/calendar"}, body: v1},
          {status: 200, headers: {"Content-Type" => "text/calendar"}, body: updated1},
        )
      row = insert_calendar_row(ics_url: "https://feed.me", external_id: "abc")
      svc.sync_row(row)
      orig_updated_at = event_svc.admin_dataset(&:first)[:row_updated_at]
      Timecop.travel(3.hours.from_now) { svc.sync_row(row) }
      newly_updated_at = event_svc.admin_dataset(&:first)[:row_updated_at]
      expect(newly_updated_at).to eq(orig_updated_at)
      Timecop.travel(6.hours.from_now) { svc.sync_row(row) }
      final_updated_at = event_svc.admin_dataset(&:first)[:row_updated_at]
      expect(final_updated_at).to be > orig_updated_at
      expect(req).to have_been_made.times(3)
    end

    it "uses UTC for unrecognized timezones" do
      body = <<~ICAL
        BEGIN:VCALENDAR
        BEGIN:VEVENT
        SUMMARY:Abraham Lincoln
        UID:c7614cff-3549-4a00-9152-d25cc1fe077d
        SEQUENCE:0
        STATUS:CONFIRMED
        TRANSP:TRANSPARENT
        DTSTART;TZID=Unknown:19700101T000000
        DTEND;TZID=Unknown:19710101T000000
        END:VEVENT
        END:VCALENDAR
      ICAL
      req = stub_request(:get, "https://feed.me").
        and_return(status: 200, headers: {"Content-Type" => "text/calendar"}, body:)
      row = insert_calendar_row(ics_url: "https://feed.me", external_id: "abc")
      svc.sync_row(row)
      expect(req).to have_been_made
      expect(event_svc.admin_dataset(&:all)).to contain_exactly(
        include(
          calendar_external_id: "abc",
          start_at: Time.parse("1970-01-01T00:00:00Z"),
          end_at: Time.parse("1971-01-01T00:00:00Z"),
          uid: "c7614cff-3549-4a00-9152-d25cc1fe077d",
        ),
      )
    end

    it "handles missing timezones" do
      body = <<~ICAL
        BEGIN:VEVENT
        SEQUENCE:0
        CREATED:20130607T011211Z
        DTSTAMP:20130607T011211Z
        UID:ABCD-07DD0607-005F-011C-FF1B-0091E
        SUMMARY:Management Team Call
        DTSTART;TZID=America/New_York:20121001T140000
        DTEND:20121001T190000Z
        RRULE:FREQ=YEARLY;UNTIL=20130101T000000Z
        LAST-MODIFIED:20130607T011211Z
        END:VEVENT
      ICAL
      req = stub_request(:get, "https://feed.me").
        and_return(status: 200, headers: {"Content-Type" => "text/calendar"}, body:)
      row = insert_calendar_row(ics_url: "https://feed.me", external_id: "abc")
      svc.sync_row(row)
      expect(req).to have_been_made
      expect(event_svc.admin_dataset(&:all)).to contain_exactly(
        include(
          start_at: match_time("2012-10-01T18:00:00Z"),
          end_at: match_time("2012-10-01T19:00:00Z"),
        ),
      )
    end

    it "assumes a UTC end date if it is missing TZID but start date has it" do
      body = <<~ICAL
        BEGIN:VEVENT
        CREATED:20240926T125710Z
        DTEND:20240926T210000
        DTSTART;TZID=US/Eastern:20240926T160000
        LAST-MODIFIED:20240926T125710Z
        RRULE:FREQ=WEEKLY;UNTIL=20241003T200000Z
        UID:003CEEF7-23D0-4F95-96F3-FF3EAEBD155A
        DTSTAMP:20240926T134830Z
        END:VEVENT
      ICAL
      req = stub_request(:get, "https://feed.me").
        and_return(status: 200, headers: {"Content-Type" => "text/calendar"}, body:)
      row = insert_calendar_row(ics_url: "https://feed.me", external_id: "abc")
      Timecop.freeze("2024-09-25 20:00:00") do
        svc.sync_row(row)
      end
      expect(req).to have_been_made
      expect(event_svc.admin_dataset(&:all)).to include(
        include(
          start_at: match_time("2024-09-26T20:00:00Z"),
          end_at: match_time("2024-09-26T21:00:00Z"),
          data: hash_including(
            "DTSTART" => {"TZID" => "US/Eastern", "v" => "20240926T160000"},
            "DTEND" => {"v" => "20240926T210000Z"},
          ),
        ),
      )
    end

    it "errors for an invalid start/end time with recurrence" do
      body = <<~ICAL
        BEGIN:VEVENT
        SEQUENCE:0
        CREATED:20130607T011211Z
        DTSTAMP:20130607T011211Z
        UID:ABCD-07DD0607-005F-011C-FF1B-0091E
        SUMMARY:Management Team Call
        DTSTART;TZID=America/New_York:20121001T140000
        DTEND:20121001T190000.0
        RRULE:FREQ=YEARLY;UNTIL=20130101T000000Z
        LAST-MODIFIED:20130607T011211Z
        END:VEVENT
      ICAL
      req = stub_request(:get, "https://feed.me").
        and_return(status: 200, headers: {"Content-Type" => "text/calendar"}, body:)
      row = insert_calendar_row(ics_url: "https://feed.me", external_id: "abc")
      expect do
        svc.sync_row(row)
      end.to raise_error(/Cannot create ical entry from/)
      expect(req).to have_been_made
    end

    it "cancels events added previously no longer present in the calendar" do
      body1 = <<~ICAL
        BEGIN:VEVENT
        UID:keep_existing
        DTSTART:20080212
        DTEND:20080213
        LAST-MODIFIED:20150421T141403Z
        END:VEVENT
        BEGIN:VEVENT
        UID:go_away
        DTSTART:20080212
        DTEND:20080213
        LAST-MODIFIED:20150421T141403Z
        END:VEVENT
        BEGIN:VEVENT
        UID:recurring1
        DTSTART:20080212
        DTEND:20080213
        LAST-MODIFIED:20150421T141403Z
        RRULE:FREQ=YEARLY;UNTIL=20110101T000000Z
        END:VEVENT
      ICAL
      body2 = <<~ICAL
        BEGIN:VEVENT
        UID:keep_existing
        DTSTART:20080212
        DTEND:20080213
        LAST-MODIFIED:20150421T141403Z
        END:VEVENT
        BEGIN:VEVENT
        UID:recurring2
        DTSTART:20080212
        DTEND:20080213
        LAST-MODIFIED:20150421T141403Z
        RRULE:FREQ=YEARLY;UNTIL=20110101T000000Z
        END:VEVENT
      ICAL
      req = stub_request(:get, "https://feed.me").
        and_return(
          {status: 200, headers: {"Content-Type" => "text/calendar"}, body: body1},
          {status: 200, headers: {"Content-Type" => "text/calendar"}, body: body1},
          {status: 200, headers: {"Content-Type" => "text/calendar"}, body: body2},
        )
      abc_cal_row = insert_calendar_row(ics_url: "https://feed.me", external_id: "abc")
      # Make sure these events are not canceled while we cancel abc's (ensure we limit the dataset)
      xyz_cal_row = insert_calendar_row(ics_url: "https://feed.me", external_id: "xyz")
      svc.sync_row(abc_cal_row)
      svc.sync_row(xyz_cal_row)
      expect(event_svc.admin_dataset(&:all)).to contain_exactly(
        hash_including(compound_identity: "abc-keep_existing"),
        hash_including(compound_identity: "abc-go_away"),
        hash_including(compound_identity: "abc-recurring1-0"),
        hash_including(compound_identity: "abc-recurring1-1"),
        hash_including(compound_identity: "abc-recurring1-2"),
        hash_including(compound_identity: "xyz-keep_existing"),
        hash_including(compound_identity: "xyz-go_away"),
        hash_including(compound_identity: "xyz-recurring1-0"),
        hash_including(compound_identity: "xyz-recurring1-1"),
        hash_including(compound_identity: "xyz-recurring1-2"),
      )
      svc.sync_row(abc_cal_row)
      expect(req).to have_been_made.times(3)
      expect(event_svc.admin_dataset(&:all)).to contain_exactly(
        hash_including(compound_identity: "abc-keep_existing", status: nil),
        hash_including(compound_identity: "abc-go_away", status: "CANCELLED", data: hash_including("UID", "STATUS" => {"v" => "CANCELLED"})),
        hash_including(compound_identity: "abc-recurring1-0", status: "CANCELLED", data: hash_including("UID", "STATUS" => {"v" => "CANCELLED"})),
        hash_including(compound_identity: "abc-recurring1-1", status: "CANCELLED", data: hash_including("UID", "STATUS" => {"v" => "CANCELLED"})),
        hash_including(compound_identity: "abc-recurring1-2", status: "CANCELLED", data: hash_including("UID", "STATUS" => {"v" => "CANCELLED"})),
        hash_including(compound_identity: "abc-recurring2-0", status: nil),
        hash_including(compound_identity: "abc-recurring2-1", status: nil),
        hash_including(compound_identity: "abc-recurring2-2", status: nil),
        hash_including(compound_identity: "xyz-keep_existing", status: nil),
        hash_including(compound_identity: "xyz-go_away", status: nil),
        hash_including(compound_identity: "xyz-recurring1-0", status: nil),
        hash_including(compound_identity: "xyz-recurring1-1", status: nil),
        hash_including(compound_identity: "xyz-recurring1-2", status: nil),
      )
    end

    it "updates row_updated_at when canceling an event" do
      body1 = <<~ICAL
        BEGIN:VEVENT
        UID:keep
        DTSTART:20080212
        DTEND:20080213
        LAST-MODIFIED:20150421T141403Z
        END:VEVENT
        BEGIN:VEVENT
        UID:already_cancelled
        DTSTART:20080212
        DTEND:20080213
        STATUS:CANCELLED
        LAST-MODIFIED:20150421T141403Z
        END:VEVENT
        BEGIN:VEVENT
        UID:will_cancel
        DTSTART:20080212
        DTEND:20080213
        LAST-MODIFIED:20150421T141403Z
        END:VEVENT
      ICAL
      body2 = <<~ICAL
        BEGIN:VEVENT
        UID:keep
        DTSTART:20080212
        DTEND:20080213
        LAST-MODIFIED:20150421T141403Z
        END:VEVENT
        BEGIN:VEVENT
        UID:already_cancelled
        DTSTART:20080212
        DTEND:20080213
        STATUS:CANCELLED
        LAST-MODIFIED:20150421T141403Z
        END:VEVENT
      ICAL
      req = stub_request(:get, "https://feed.me").
        and_return(
          {status: 200, headers: {"Content-Type" => "text/calendar"}, body: body1},
          {status: 200, headers: {"Content-Type" => "text/calendar"}, body: body2},
          {status: 200, headers: {"Content-Type" => "text/calendar"}, body: body2},
        )
      cal_row = insert_calendar_row(ics_url: "https://feed.me", external_id: "abc")
      first_ran = Time.parse("2020-01-15T12:00:00Z")
      Timecop.freeze(first_ran) do
        svc.sync_row(cal_row)
      end
      expect(event_svc.admin_dataset(&:all)).to contain_exactly(
        hash_including(compound_identity: "abc-keep", status: nil, row_updated_at: match_time(first_ran)),
        hash_including(compound_identity: "abc-already_cancelled", status: "CANCELLED", row_updated_at: match_time(first_ran)),
        hash_including(compound_identity: "abc-will_cancel", status: nil, row_updated_at: match_time(first_ran)),
      )
      second_ran = first_ran + 1.hour
      Timecop.freeze(second_ran) do
        svc.sync_row(cal_row)
      end
      expect(event_svc.admin_dataset(&:all)).to contain_exactly(
        hash_including(compound_identity: "abc-keep", status: nil, row_updated_at: match_time(first_ran)),
        hash_including(compound_identity: "abc-already_cancelled", status: "CANCELLED", row_updated_at: match_time(first_ran)),
        hash_including(compound_identity: "abc-will_cancel", status: "CANCELLED", row_updated_at: match_time(second_ran)),
      )
      third_ran = second_ran + 1.hour
      Timecop.freeze(third_ran) do
        svc.sync_row(cal_row)
      end
      expect(event_svc.admin_dataset(&:all)).to contain_exactly(
        hash_including(compound_identity: "abc-keep", status: nil, row_updated_at: match_time(first_ran)),
        hash_including(compound_identity: "abc-already_cancelled", status: "CANCELLED", row_updated_at: match_time(first_ran)),
        hash_including(compound_identity: "abc-will_cancel", status: "CANCELLED", row_updated_at: match_time(second_ran)),
      )
      expect(req).to have_been_made.times(3)
    end

    it "does a best attempt if DTSTART is a time and DTEND is a date" do
      body = <<~ICAL
        BEGIN:VEVENT
        DTEND;VALUE=DATE:20241102
        DTSTAMP:20241101T233000Z
        DTSTART;TZID=America/Los_Angeles:20241101T163000
        STATUS:CONFIRMED
        RRULE;TZID=UTC:FREQ=WEEKLY;UNTIL=20241115T075959Z
        UID:81DAC1F1-E948-486C-B3BF-2904F591FBA3
        END:VEVENT
      ICAL
      req = stub_request(:get, "https://feed.me").
        and_return(status: 200, headers: {"Content-Type" => "text/calendar"}, body:)
      row = insert_calendar_row(ics_url: "https://feed.me", external_id: "abc")
      svc.sync_row(row)
      expect(req).to have_been_made
      expect(event_svc.admin_dataset(&:all)).to contain_exactly(
        include(
          data: hash_including(
            "DTEND" => {"VALUE" => "DATE", "v" => "20241102"},
            "DTSTART" => {"TZID" => "America/Los_Angeles", "v" => "20241101T163000"},
          ),
          start_at: match_time("2024-11-01T23:30:00Z"),
          end_at: match_time("2024-11-01T23:30:00Z"),
          end_date: Date.new(2024, 11, 2),
          start_date: nil,
        ),
        include(
          start_at: match_time("2024-11-09T00:30:00Z"),
          end_at: match_time("2024-11-09T00:30:00Z"),
          end_date: Date.new(2024, 11, 2),
          start_date: nil,
        ),
      )
    end

    describe "alerting", :no_transaction_check do
      it "raises on unexpected errors" do
        err = RuntimeError.new("hi")
        req = stub_request(:get, "https://feed.me").to_raise(err)
        row = insert_calendar_row(ics_url: "https://feed.me", external_id: "abc")
        expect do
          svc.sync_row(row)
        end.to raise_error(err)
        expect(req).to have_been_made
      end

      it "alerts on too many redirects" do
        Webhookdb::Fixtures.organization_membership.org(org).verified.admin.create
        req = stub_request(:get, "https://feed.me").and_return(
          {status: 301, headers: {"Location" => "https://feed.me"}},
          {status: 301, headers: {"Location" => "https://feed.me"}},
        )
        row = insert_calendar_row(ics_url: "https://feed.me", external_id: "abc")
        svc.sync_row(row)
        expect(req).to have_been_made.times(2)
        expect(Webhookdb::Message::Delivery.all).to contain_exactly(
          have_attributes(template: "errors/icalendar_fetch"),
        )
      end

      [400, 404, 417, 422, 500, 503].each do |httpstatus|
        it "alerts on HTTP #{httpstatus} errors" do
          Webhookdb::Fixtures.organization_membership.org(org).verified.admin.create
          req = stub_request(:get, "https://feed.me").
            and_return(status: httpstatus, headers: {"Content-Type" => "text/plain"}, body: "whoops")
          row = insert_calendar_row(ics_url: "https://feed.me", external_id: "abc")
          svc.sync_row(row)
          expect(req).to have_been_made
          expect(Webhookdb::Message::Delivery.all).to contain_exactly(
            have_attributes(template: "errors/icalendar_fetch"),
          )
        end
      end

      it "unwraps an Ical-Proxy-Origin-Error header into a status code", reset_configuration: Webhookdb::Icalendar do
        Webhookdb::Icalendar.proxy_url = "https://proxy"
        Webhookdb::Fixtures.organization_membership.org(org).verified.admin.create
        req = stub_request(:get, "https://proxy?url=https://feed.me").
          and_return(status: 421, headers: {"Ical-Proxy-Origin-Error" => 599}, body: "whoops")
        row = insert_calendar_row(ics_url: "https://feed.me", external_id: "abc")
        svc.sync_row(row)
        expect(req).to have_been_made
        expect(Webhookdb::Message::Delivery.all).to contain_exactly(
          have_attributes(template: "errors/icalendar_fetch"),
        )
        # Ensure the proxy fields aren't in the email
        body = Webhookdb::Message::Body.where(mediatype: "text/plain").first.content
        expect(body).to include("Request: GET https://feed.me")
        expect(body).to include("Response Status: 599")
      end

      it "noops on 304 responses" do
        Webhookdb::Fixtures.organization_membership.org(org).verified.admin.create
        req = stub_request(:get, "https://feed.me").
          and_return(status: 304)
        row = insert_calendar_row(ics_url: "https://feed.me", external_id: "abc")
        svc.sync_row(row)
        expect(req).to have_been_made
        expect(Webhookdb::Message::Delivery.all).to be_empty
      end

      it "alerts on redirect without a Location header" do
        Webhookdb::Fixtures.organization_membership.org(org).verified.admin.create
        req = stub_request(:get, "https://feed.me").
          and_return(status: 307, headers: {})
        row = insert_calendar_row(ics_url: "https://feed.me", external_id: "abc")
        svc.sync_row(row)
        expect(req).to have_been_made
        expect(Webhookdb::Message::Delivery.all).to contain_exactly(
          have_attributes(template: "errors/icalendar_fetch"),
        )
      end

      [
        ["429s", {status: 429}],
        ["ssl errors", OpenSSL::SSL::SSLError.new],
      ].each do |(msg, param)|
        it "retries on #{msg}" do
          Webhookdb::Fixtures.organization_membership.org(org).verified.admin.create
          req = stub_request(:get, "https://feed.me")
          req = if param.is_a?(Hash)
                  req.and_return(headers: {"Content-Type" => "text/plain"}, body: "whoops", **param)
          else
            req.and_raise(param)
                end
          row = insert_calendar_row(ics_url: "https://feed.me", external_id: "abc")
          expect { svc.sync_row(row) }.to raise_error(Amigo::Retry::OrDie)
          expect(req).to have_been_made
        end
      end

      describe "with a real test server" do
        include Webhookdb::SpecHelpers::Http::TestServer

        it "handles connection errors during body reading, like resets" do
          Webhookdb::Fixtures.organization_membership.org(org).verified.admin.create
          test_server_responses.push lambda { |env|
            env["rack.hijack"].call # Tell Rack we're hijacking
            io = env["rack.hijack_io"]

            # Set SO_LINGER to { onoff: 1, linger: 0 } to trigger an RST on close
            # This is pretty in the weeds stuff, ChatGPT helped figure it out.
            linger = [1, 0].pack("ii")
            io.setsockopt(Socket::SOL_SOCKET, Socket::SO_LINGER, linger)

            io.write("HTTP/1.1 200 OK\r\n")
            io.write("Content-Type: text/plain\r\n")
            # Set a large content length, we won't send it all
            io.write("Content-Length: 10000000\r\n")
            io.write("Connection: close\r\n")
            io.write("\r\n")
            # Send enough of the body to get a first readpartial to finish (> 17kb).
            io.write("BEGIN:VEVENT\nENV:VEVENT\n" * 700)
            # Abruptly close the connection
            io.close
            # Rack requires a return value, but it will be ignored after hijack
            [-1, {}, []]
          }
          row = insert_calendar_row(ics_url: test_server_url + "/feed", external_id: "abc")
          svc.sync_row(row)
          expect(Webhookdb::Message::Delivery.all).to contain_exactly(
            have_attributes(template: "errors/icalendar_fetch"),
          )
        end
      end

      it "alerts on 429s to particular URLs" do
        Webhookdb::Fixtures.organization_membership.org(org).verified.admin.create
        req = stub_request(:get, "https://ical.schedulestar.com/fans/?uuid=123").
          and_return(status: 429)
        row = insert_calendar_row(ics_url: "https://ical.schedulestar.com/fans/?uuid=123", external_id: "abc")
        svc.sync_row(row)
        expect(req).to have_been_made
        expect(Webhookdb::Message::Delivery.all).to contain_exactly(
          have_attributes(template: "errors/icalendar_fetch"),
        )
      end

      it "alerts on invalid url errors" do
        Webhookdb::Fixtures.organization_membership.org(org).verified.admin.create
        row = insert_calendar_row(ics_url: "webca://feed.me", external_id: "abc")
        svc.sync_row(row)
        expect(Webhookdb::Message::Delivery.all).to contain_exactly(
          have_attributes(template: "errors/icalendar_fetch"),
        )
      end

      it "alerts on non-UTF8 url errors" do
        Webhookdb::Fixtures.organization_membership.org(org).verified.admin.create
        row = insert_calendar_row(ics_url: "https://outlook.office365.com/\u2026acmecorp.com/", external_id: "abc")
        svc.sync_row(row)
        expect(Webhookdb::Message::Delivery.all).to contain_exactly(
          have_attributes(template: "errors/icalendar_fetch"),
        )
      end

      it "alerts on timeout" do
        Webhookdb::Fixtures.organization_membership.org(org).verified.admin.create
        req = stub_request(:get, "https://feed.me").to_raise(HTTP::TimeoutError)
        row = insert_calendar_row(ics_url: "https://feed.me", external_id: "abc")
        svc.sync_row(row)
        expect(req).to have_been_made
        expect(Webhookdb::Message::Delivery.all).to contain_exactly(
          have_attributes(template: "errors/icalendar_fetch"),
        )
      end

      [
        ["certificate failures", "certificate verify failed (certificate has expired)"],
        ["legacy TLS", "unsafe legacy renegotiation disabled"],
      ].each do |(name, msg)|
        it "alerts on SSL #{name} errors" do
          Webhookdb::Fixtures.organization_membership.org(org).verified.admin.create
          err = OpenSSL::SSL::SSLError.new("SSL_connect returned=1 errno=0 peeraddr=216.235.207.153:443 state=error: #{msg}")
          req = stub_request(:get, "https://feed.me").to_raise(err)
          row = insert_calendar_row(ics_url: "https://feed.me", external_id: "abc")
          svc.sync_row(row)
          expect(req).to have_been_made
          expect(Webhookdb::Message::Delivery.all).to contain_exactly(
            have_attributes(template: "errors/icalendar_fetch"),
          )
        end
      end
    end

    describe "recurrence" do
      def sync(body)
        req = stub_request(:get, "https://feed.me").
          and_return(status: 200, headers: {"Content-Type" => "text/calendar"}, body:)
        row = insert_calendar_row(ics_url: "https://feed.me", external_id: "abc")
        Timecop.freeze("2022-06-06") do
          svc.sync_row(row)
        end
        expect(req).to have_been_made
        events = event_svc.admin_dataset(&:all)
        return events
      end

      it "projects all past events, and recurring events up to RECURRENCE_PROJECTION forward" do
        stub_const("Webhookdb::Replicator::IcalendarCalendarV1::RECURRENCE_PROJECTION", 2.years)
        body = <<~ICAL
          BEGIN:VEVENT
          SUMMARY:Abraham Lincoln
          UID:c7614cff-3549-4a00-9152-d25cc1fe077d
          DTSTART:20180101T000000Z
          DTEND:20180101T010000Z
          RRULE:FREQ=YEARLY;UNTIL=30700101T000000Z
          END:VEVENT
        ICAL
        expect(sync(body)).to contain_exactly(
          hash_including(compound_identity: "abc-c7614cff-3549-4a00-9152-d25cc1fe077d-0", calendar_external_id: "abc", uid: "c7614cff-3549-4a00-9152-d25cc1fe077d-0", start_at: Time.parse("2018-01-01 00:00:00Z"), end_at: Time.parse("2018-01-01 01:00:00Z"), recurring_event_id: "c7614cff-3549-4a00-9152-d25cc1fe077d", recurring_event_sequence: 0),
          hash_including(compound_identity: "abc-c7614cff-3549-4a00-9152-d25cc1fe077d-1", calendar_external_id: "abc", uid: "c7614cff-3549-4a00-9152-d25cc1fe077d-1", start_at: Time.parse("2019-01-01 00:00:00Z"), end_at: Time.parse("2019-01-01 01:00:00Z"), recurring_event_id: "c7614cff-3549-4a00-9152-d25cc1fe077d", recurring_event_sequence: 1),
          hash_including(compound_identity: "abc-c7614cff-3549-4a00-9152-d25cc1fe077d-2", calendar_external_id: "abc", uid: "c7614cff-3549-4a00-9152-d25cc1fe077d-2", start_at: Time.parse("2020-01-01 00:00:00Z"), end_at: Time.parse("2020-01-01 01:00:00Z"), recurring_event_id: "c7614cff-3549-4a00-9152-d25cc1fe077d", recurring_event_sequence: 2),
          hash_including(compound_identity: "abc-c7614cff-3549-4a00-9152-d25cc1fe077d-3", calendar_external_id: "abc", uid: "c7614cff-3549-4a00-9152-d25cc1fe077d-3", start_at: Time.parse("2021-01-01 00:00:00Z"), end_at: Time.parse("2021-01-01 01:00:00Z"), recurring_event_id: "c7614cff-3549-4a00-9152-d25cc1fe077d", recurring_event_sequence: 3),
          hash_including(compound_identity: "abc-c7614cff-3549-4a00-9152-d25cc1fe077d-4", calendar_external_id: "abc", uid: "c7614cff-3549-4a00-9152-d25cc1fe077d-4", start_at: Time.parse("2022-01-01 00:00:00Z"), end_at: Time.parse("2022-01-01 01:00:00Z"), recurring_event_id: "c7614cff-3549-4a00-9152-d25cc1fe077d", recurring_event_sequence: 4),
          hash_including(compound_identity: "abc-c7614cff-3549-4a00-9152-d25cc1fe077d-5", calendar_external_id: "abc", uid: "c7614cff-3549-4a00-9152-d25cc1fe077d-5", start_at: Time.parse("2023-01-01 00:00:00Z"), end_at: Time.parse("2023-01-01 01:00:00Z"), recurring_event_id: "c7614cff-3549-4a00-9152-d25cc1fe077d", recurring_event_sequence: 5),
          hash_including(compound_identity: "abc-c7614cff-3549-4a00-9152-d25cc1fe077d-6", calendar_external_id: "abc", uid: "c7614cff-3549-4a00-9152-d25cc1fe077d-6", start_at: Time.parse("2024-01-01 00:00:00Z"), end_at: Time.parse("2024-01-01 01:00:00Z"), recurring_event_id: "c7614cff-3549-4a00-9152-d25cc1fe077d", recurring_event_sequence: 6),
          hash_including(compound_identity: "abc-c7614cff-3549-4a00-9152-d25cc1fe077d-7", calendar_external_id: "abc", uid: "c7614cff-3549-4a00-9152-d25cc1fe077d-7", start_at: Time.parse("2025-01-01 00:00:00Z"), end_at: Time.parse("2025-01-01 01:00:00Z"), recurring_event_id: "c7614cff-3549-4a00-9152-d25cc1fe077d", recurring_event_sequence: 7),
        )
      end

      it "stops projecting at the UNTIL" do
        body = <<~ICAL
          BEGIN:VEVENT
          SUMMARY:Abraham Lincoln
          UID:c7614cff-3549-4a00-9152-d25cc1fe077d
          DTSTART:20180101T000000Z
          DTEND:20180101T010000Z
          RRULE:FREQ=YEARLY;UNTIL=20200101T000000Z
          END:VEVENT
        ICAL
        expect(sync(body)).to contain_exactly(
          hash_including(compound_identity: "abc-c7614cff-3549-4a00-9152-d25cc1fe077d-0", start_at: Time.parse("2018-01-01 00:00:00Z"), end_at: Time.parse("2018-01-01 01:00:00Z")),
          hash_including(compound_identity: "abc-c7614cff-3549-4a00-9152-d25cc1fe077d-1", start_at: Time.parse("2019-01-01 00:00:00Z"), end_at: Time.parse("2019-01-01 01:00:00Z")),
          hash_including(compound_identity: "abc-c7614cff-3549-4a00-9152-d25cc1fe077d-2", start_at: Time.parse("2020-01-01 00:00:00Z"), end_at: Time.parse("2020-01-01 01:00:00Z")),
        )
      end

      it "can project dates" do
        body = <<~ICAL
          BEGIN:VEVENT
          SUMMARY:Abraham Lincoln
          UID:c7614cff-3549-4a00-9152-d25cc1fe077d
          DTSTART;VALUE=DATE:20180101
          DTEND;VALUE=DATE:20180102
          RRULE:FREQ=YEARLY;UNTIL=20191201T000000Z
          END:VEVENT
        ICAL
        expect(sync(body)).to contain_exactly(
          hash_including(start_date: Date.new(2018, 1, 1), end_date: Date.new(2018, 1, 2)),
          hash_including(start_date: Date.new(2019, 1, 1), end_date: Date.new(2019, 1, 2)),
        )
      end

      it "handles EXDATE (exclusion dates)" do
        body = <<~ICAL
          BEGIN:VEVENT
          SUMMARY:Abraham Lincoln
          UID:c7614cff-3549-4a00-9152-d25cc1fe077d
          DTSTART:20180101T000000Z
          DTEND:20180101T010000Z
          RRULE:FREQ=YEARLY;UNTIL=20210101T000000Z
          EXDATE:20180101T000000Z
          EXDATE;TZID=Africa/Algiers:20200101T010000
          END:VEVENT
        ICAL
        rows = sync(body)
        expect(rows).to contain_exactly(
          hash_including(start_at: match_time("2019-01-01T00:00:00Z")),
          hash_including(start_at: match_time("2021-01-01T00:00:00Z")),
        )
      end

      it "handles RDATE (inclusion dates)" do
        body = <<~ICAL
          BEGIN:VEVENT
          SUMMARY:Abraham Lincoln
          UID:c7614cff-3549-4a00-9152-d25cc1fe077d
          DTSTART:20180101T000000Z
          DTEND:20180101T010000Z
          RRULE:FREQ=YEARLY;UNTIL=20190101T000000Z
          RDATE;TZID=Africa/Algiers:20180301T010000
          RDATE:20200401T000000Z
          END:VEVENT
        ICAL
        rows = sync(body)
        expect(rows).to contain_exactly(
          hash_including(start_at: match_time("2018-01-01T00:00:00Z")),
          hash_including(start_at: match_time("2018-03-01T00:00:00Z")),
          hash_including(start_at: match_time("2019-01-01T00:00:00Z")),
          hash_including(start_at: match_time("2020-04-01T00:00:00Z")),
        )
      end

      it "handles RDATE and EXDATE date values" do
        body = <<~ICAL
          BEGIN:VEVENT
          SUMMARY:Abraham Lincoln
          UID:c7614cff-3549-4a00-9152-d25cc1fe077d
          DTSTART;VALUE=DATE:20180101
          DTEND;VALUE=DATE:20180101
          RRULE:FREQ=YEARLY;UNTIL=20190101
          RDATE;VALUE=DATE:20180301
          EXDATE;VALUE=DATE:20180101
          END:VEVENT
        ICAL
        rows = sync(body)
        expect(rows).to contain_exactly(
          hash_including(start_date: Date.new(2018, 3, 1)),
          hash_including(start_date: Date.new(2019, 1, 1)),
        )
      end

      it "handles events with no end time" do
        body = <<~ICAL
          BEGIN:VEVENT
          SUMMARY:Abraham Lincoln
          UID:c7614cff-3549-4a00-9152-d25cc1fe077d
          DTSTART:20180101T000000Z
          RRULE:FREQ=YEARLY;UNTIL=20200101T000000Z
          END:VEVENT
        ICAL
        expect(sync(body)).to contain_exactly(
          hash_including(compound_identity: "abc-c7614cff-3549-4a00-9152-d25cc1fe077d-0", start_at: Time.parse("2018-01-01 00:00:00Z"), end_at: Time.parse("2018-01-01 00:00:00Z")),
          hash_including(compound_identity: "abc-c7614cff-3549-4a00-9152-d25cc1fe077d-1", start_at: Time.parse("2019-01-01 00:00:00Z"), end_at: Time.parse("2019-01-01 00:00:00Z")),
          hash_including(compound_identity: "abc-c7614cff-3549-4a00-9152-d25cc1fe077d-2", start_at: Time.parse("2020-01-01 00:00:00Z"), end_at: Time.parse("2020-01-01 00:00:00Z")),
        )
      end

      it "deletes future, unmodified recurring events" do
        body1 = <<~ICAL
          BEGIN:VEVENT
          SUMMARY:Abraham Lincoln
          UID:c7614cff-3549-4a00-9152-d25cc1fe077d
          DTSTART:20180101T000000Z
          RRULE:FREQ=YEARLY;UNTIL=20230101T000000Z
          END:VEVENT
        ICAL
        body2 = <<~ICAL
          BEGIN:VEVENT
          SUMMARY:Abraham Lincoln
          UID:c7614cff-3549-4a00-9152-d25cc1fe077d
          DTSTART:20180101T000000Z
          RRULE:FREQ=YEARLY;UNTIL=20210101T000000Z
          END:VEVENT
        ICAL

        req = stub_request(:get, "https://feed.me").
          and_return(
            {status: 200, headers: {"Content-Type" => "text/calendar"}, body: body1},
            {status: 200, headers: {"Content-Type" => "text/calendar"}, body: body2},
          )
        cal_row = insert_calendar_row(ics_url: "https://feed.me", external_id: "abc")

        Timecop.freeze("2022-06-06") do
          svc.sync_row(cal_row)
        end
        events1 = event_svc.admin_dataset(&:all)
        expect(events1).to contain_exactly(
          hash_including(compound_identity: "abc-c7614cff-3549-4a00-9152-d25cc1fe077d-0", start_at: Time.parse("2018-01-01 00:00:00Z")),
          hash_including(compound_identity: "abc-c7614cff-3549-4a00-9152-d25cc1fe077d-1", start_at: Time.parse("2019-01-01 00:00:00Z")),
          hash_including(compound_identity: "abc-c7614cff-3549-4a00-9152-d25cc1fe077d-2", start_at: Time.parse("2020-01-01 00:00:00Z")),
          hash_including(compound_identity: "abc-c7614cff-3549-4a00-9152-d25cc1fe077d-3", start_at: Time.parse("2021-01-01 00:00:00Z")),
          hash_including(compound_identity: "abc-c7614cff-3549-4a00-9152-d25cc1fe077d-4", start_at: Time.parse("2022-01-01 00:00:00Z")),
          hash_including(compound_identity: "abc-c7614cff-3549-4a00-9152-d25cc1fe077d-5", start_at: Time.parse("2023-01-01 00:00:00Z")),
        )

        Timecop.freeze("2022-06-06") do
          svc.sync_row(cal_row)
        end
        events2 = event_svc.admin_dataset(&:all)
        expect(events2).to contain_exactly(
          hash_including(compound_identity: "abc-c7614cff-3549-4a00-9152-d25cc1fe077d-0", start_at: Time.parse("2018-01-01 00:00:00Z")),
          hash_including(compound_identity: "abc-c7614cff-3549-4a00-9152-d25cc1fe077d-1", start_at: Time.parse("2019-01-01 00:00:00Z")),
          hash_including(compound_identity: "abc-c7614cff-3549-4a00-9152-d25cc1fe077d-2", start_at: Time.parse("2020-01-01 00:00:00Z")),
          hash_including(compound_identity: "abc-c7614cff-3549-4a00-9152-d25cc1fe077d-3", start_at: Time.parse("2021-01-01 00:00:00Z")),
        )

        expect(req).to have_been_made.times(2)
      end

      it "deletes everything if the event does not recur" do
        body1 = <<~ICAL
          BEGIN:VEVENT
          SUMMARY:Abraham Lincoln
          UID:c7614cff-3549-4a00-9152-d25cc1fe077d
          DTSTART:20180101T000000Z
          RRULE:FREQ=YEARLY;UNTIL=20230101T000000Z
          END:VEVENT
        ICAL
        body2 = <<~ICAL
          BEGIN:VEVENT
          SUMMARY:Abraham Lincoln
          UID:c7614cff-3549-4a00-9152-d25cc1fe077d
          DTSTART:20180101T000000Z
          RRULE:FREQ=YEARLY;UNTIL=20100101T000000Z
          END:VEVENT
        ICAL

        req = stub_request(:get, "https://feed.me").
          and_return(
            {status: 200, headers: {"Content-Type" => "text/calendar"}, body: body1},
            {status: 200, headers: {"Content-Type" => "text/calendar"}, body: body2},
          )
        cal_row = insert_calendar_row(ics_url: "https://feed.me", external_id: "abc")

        Timecop.freeze("2022-06-06") do
          svc.sync_row(cal_row)
        end
        events1 = event_svc.admin_dataset(&:all)
        expect(events1).to have_length(6)

        Timecop.freeze("2022-06-06") do
          svc.sync_row(cal_row)
        end
        events2 = event_svc.admin_dataset(&:all)
        expect(events2).to be_empty

        expect(req).to have_been_made.times(2)
      end

      it "handles exception dates via recurrence-id field" do
        body1 = <<~ICAL
          BEGIN:VCALENDAR
          PRODID:-//Google Inc//Google Calendar 70.9054//EN
          VERSION:2.0
          BEGIN:VEVENT
          DTSTART;TZID=America/New_York:20230623T163000
          DTEND;TZID=America/New_York:20230623T170000
          RRULE:FREQ=DAILY;COUNT=4
          DTSTAMP:20230623T215026Z
          UID:73k3lgpbrb53fvdlv4m4jq9a5e@google.com
          CREATED:20230623T214717Z
          LAST-MODIFIED:20230623T214935Z
          SEQUENCE:0
          STATUS:CONFIRMED
          SUMMARY:Test Recur
          TRANSP:OPAQUE
          END:VEVENT
          END:VCALENDAR
        ICAL
        body2 = <<~ICAL
          BEGIN:VCALENDAR
          PRODID:-//Google Inc//Google Calendar 70.9054//EN
          VERSION:2.0
          BEGIN:VEVENT
          DTSTART;TZID=America/New_York:20230623T163000
          DTEND;TZID=America/New_York:20230623T170000
          RRULE:FREQ=DAILY;COUNT=4
          DTSTAMP:20230623T215026Z
          UID:73k3lgpbrb53fvdlv4m4jq9a5e@google.com
          CREATED:20230623T214717Z
          LAST-MODIFIED:20230623T214935Z
          SEQUENCE:0
          STATUS:CONFIRMED
          SUMMARY:Test Recur
          TRANSP:OPAQUE
          END:VEVENT
          BEGIN:VEVENT
          DTSTART;TZID=America/New_York:20230624T163000
          DTEND;TZID=America/New_York:20230624T171500
          DTSTAMP:20230623T215026Z
          UID:73k3lgpbrb53fvdlv4m4jq9a5e@google.com
          RECURRENCE-ID;TZID=America/New_York:20230624T163000
          CREATED:20230623T214717Z
          LAST-MODIFIED:20230623T214935Z
          SEQUENCE:0
          STATUS:CONFIRMED
          SUMMARY:Test Recur - Exception
          TRANSP:OPAQUE
          END:VEVENT
          END:VCALENDAR
        ICAL
        req = stub_request(:get, "https://feed.me").
          and_return(
            {status: 200, headers: {"Content-Type" => "text/calendar"}, body: body1},
            {status: 200, headers: {"Content-Type" => "text/calendar"}, body: body2},
          )
        cal_row = insert_calendar_row(ics_url: "https://feed.me", external_id: "abc")

        Timecop.freeze("2023-06-20") do
          svc.sync_row(cal_row)
        end
        events1 = event_svc.admin_dataset { |ds| ds.select(:compound_identity, :start_at, :end_at).all }
        expect(events1).to contain_exactly(
          hash_including(
            compound_identity: "abc-73k3lgpbrb53fvdlv4m4jq9a5e@google.com-0",
            start_at: match_time("2023-06-23 20:30:00 +0000"),
            end_at: match_time("2023-06-23 21:00:00 +0000"),
          ),
          hash_including(
            compound_identity: "abc-73k3lgpbrb53fvdlv4m4jq9a5e@google.com-1",
            start_at: match_time("2023-06-24 20:30:00 +0000"),
            end_at: match_time("2023-06-24 21:00:00 +0000"),
          ),
          hash_including(
            compound_identity: "abc-73k3lgpbrb53fvdlv4m4jq9a5e@google.com-2",
            start_at: match_time("2023-06-25 20:30:00 +0000"),
            end_at: match_time("2023-06-25 21:00:00 +0000"),
          ),
          hash_including(
            compound_identity: "abc-73k3lgpbrb53fvdlv4m4jq9a5e@google.com-3",
            start_at: match_time("2023-06-26 20:30:00 +0000"),
            end_at: match_time("2023-06-26 21:00:00 +0000"),
          ),
        )

        Timecop.freeze("2022-06-06") do
          svc.sync_row(cal_row)
        end
        events2 = event_svc.admin_dataset { |ds| ds.select(:compound_identity, :start_at, :end_at).all }
        expect(events2).to contain_exactly(
          hash_including(
            compound_identity: "abc-73k3lgpbrb53fvdlv4m4jq9a5e@google.com-0",
            start_at: match_time("2023-06-23 20:30:00 +0000"),
            end_at: match_time("2023-06-23 21:00:00 +0000"),
          ),
          # This is the modified event, with a new end time (9:15)
          hash_including(
            compound_identity: "abc-73k3lgpbrb53fvdlv4m4jq9a5e@google.com-1",
            start_at: match_time("2023-06-24 20:30:00 +0000"),
            end_at: match_time("2023-06-24 21:15:00 +0000"),
          ),
          hash_including(
            compound_identity: "abc-73k3lgpbrb53fvdlv4m4jq9a5e@google.com-2",
            start_at: match_time("2023-06-25 20:30:00 +0000"),
            end_at: match_time("2023-06-25 21:00:00 +0000"),
          ),
          hash_including(
            compound_identity: "abc-73k3lgpbrb53fvdlv4m4jq9a5e@google.com-3",
            start_at: match_time("2023-06-26 20:30:00 +0000"),
            end_at: match_time("2023-06-26 21:00:00 +0000"),
          ),
        )

        expect(req).to have_been_made.times(2)
      end

      it "handles recurrence-id datetimes that do not match any RRULE" do
        body = <<~ICAL
          BEGIN:VCALENDAR
          PRODID:-//Google Inc//Google Calendar 70.9054//EN
          VERSION:2.0
          BEGIN:VEVENT
          CREATED:20160921T163517Z
          DTEND;TZID=America/New_York:20160923T200000
          DTSTAMP:20161111T235102Z
          DTSTART;TZID=America/New_York:20160923T190000
          LAST-MODIFIED:20160921T163518Z
          RRULE:FREQ=WEEKLY;UNTIL=20161007T230000Z
          SEQUENCE:0
          SUMMARY:Boys MA
          UID:2A389DBC-C85E-4A98-8817-8F5C0059DEB6
          END:VEVENT
          BEGIN:VEVENT
          CREATED:20161111T232837Z
          DTEND;TZID=America/New_York:20161111T200000
          DTSTAMP:20161111T235102Z
          DTSTART;TZID=America/New_York:20161111T190000
          LAST-MODIFIED:20161111T232837Z
          RECURRENCE-ID;TZID=America/New_York:20161111T190000
          SEQUENCE:0
          SUMMARY:Boys MA
          UID:2A389DBC-C85E-4A98-8817-8F5C0059DEB6
          END:VEVENT
          END:VCALENDAR
        ICAL
        req = stub_request(:get, "https://feed.me").
          and_return(status: 200, headers: {"Content-Type" => "text/calendar"}, body:)
        cal_row = insert_calendar_row(ics_url: "https://feed.me", external_id: "abc")

        event_svc.admin_dataset do |ds|
          # Make sure this gets deleted
          ds.insert(
            data: "{}",
            compound_identity: "abc-2A389DBC-C85E-4A98-8817-8F5C0059DEB6-4",
            calendar_external_id: "abc",
            recurring_event_id: "2A389DBC-C85E-4A98-8817-8F5C0059DEB6",
            recurring_event_sequence: 4,
          )
        end

        svc.sync_row(cal_row)
        expect(req).to have_been_made

        events = event_svc.admin_dataset(&:all)
        expect(events).to contain_exactly(
          include(
            compound_identity: "abc-2A389DBC-C85E-4A98-8817-8F5C0059DEB6-0",
            start_at: match_time("2016-09-23 23:00:00 +0000"),
            end_at: match_time("2016-09-24 00:00:00 +0000"),
          ),
          include(
            compound_identity: "abc-2A389DBC-C85E-4A98-8817-8F5C0059DEB6-1",
            start_at: match_time("2016-09-30 23:00:00 +0000"),
            end_at: match_time("2016-10-01 00:00:00 +0000"),
          ),
          include(
            compound_identity: "abc-2A389DBC-C85E-4A98-8817-8F5C0059DEB6-2",
            start_at: match_time("2016-10-07 23:00:00 +0000"),
            end_at: match_time("2016-10-08 00:00:00 +0000"),
          ),
          include(
            compound_identity: "abc-2A389DBC-C85E-4A98-8817-8F5C0059DEB6-3",
            start_at: match_time("2016-11-12 00:00:00 +0000"),
            end_at: match_time("2016-11-12 01:00:00 +0000"),
            recurring_event_id: "2A389DBC-C85E-4A98-8817-8F5C0059DEB6",
            recurring_event_sequence: 3,
          ),
        )
      end

      it "handles recurrence-id that does not have a corresponding UID" do
        body = <<~ICAL
          BEGIN:VCALENDAR
          PRODID:-//Google Inc//Google Calendar 70.9054//EN
          VERSION:2.0
          BEGIN:VEVENT
          DTEND;VALUE=DATE:20110215
          DTSTAMP:20111029T235747Z
          DTSTART;VALUE=DATE:20110214
          LAST-MODIFIED:20110131T011428Z
          RECURRENCE-ID:20110214T000000
          SEQUENCE:0
          STATUS:CONFIRMED
          SUMMARY:Valentines day!
          TRANSP:OPAQUE
          UID:09490091-F30F-4391-AEB4-945A3EAFC2D1
          BEGIN:VALARM
          ACTION:DISPLAY
          DESCRIPTION:Event reminder
          TRIGGER;VALUE=DURATION:-P2D
          X-WR-ALARMUID:F25C19ED-F345-4B11-A71C-6F9B354ABD41
          END:VALARM
          END:VEVENT
          END:VCALENDAR
        ICAL
        req = stub_request(:get, "https://feed.me").
          and_return(status: 200, headers: {"Content-Type" => "text/calendar"}, body:)
        cal_row = insert_calendar_row(ics_url: "https://feed.me", external_id: "abc")

        svc.sync_row(cal_row)
        expect(req).to have_been_made

        events = event_svc.admin_dataset(&:all)
        expect(events).to contain_exactly(
          include(
            compound_identity: "abc-09490091-F30F-4391-AEB4-945A3EAFC2D1",
            start_date: Date.parse("20110214"),
            end_date: Date.parse("20110215"),
            recurring_event_id: nil,
            recurring_event_sequence: nil,
          ),
        )
      end

      it "handles times without zones" do
        body = <<~ICAL
          BEGIN:VCALENDAR
          PRODID:-//Google Inc//Google Calendar 70.9054//EN
          VERSION:2.0
          BEGIN:VEVENT
          CREATED:20161111T232837Z
          DTEND:20161111T200000
          DTSTAMP:20161111T235102Z
          DTSTART:20161111T190000
          LAST-MODIFIED:20161111T232837Z
          SEQUENCE:0
          SUMMARY:Boys MA
          UID:missingtz
          END:VEVENT
          BEGIN:VEVENT
          CREATED:20161111T232837Z
          DTEND:20161111T200000Z
          DTSTAMP:20161111T235102Z
          DTSTART:20161111T190000Z
          LAST-MODIFIED:20161111T232837Z
          SEQUENCE:0
          SUMMARY:Boys MA
          UID:hastz
          END:VEVENT
          END:VCALENDAR
        ICAL
        req = stub_request(:get, "https://feed.me").
          and_return(status: 200, headers: {"Content-Type" => "text/calendar"}, body:)
        cal_row = insert_calendar_row(ics_url: "https://feed.me", external_id: "abc")

        svc.sync_row(cal_row)
        expect(req).to have_been_made

        events = event_svc.admin_dataset(&:all)
        expect(events).to contain_exactly(
          include(
            compound_identity: "abc-missingtz",
            start_at: match_time("2016-11-11 19:00:00 +0000"),
            end_at: match_time("2016-11-11 20:00:00 +0000"),
            missing_timezone: true,
          ),
          include(
            compound_identity: "abc-hastz",
            start_at: match_time("2016-11-11 19:00:00 +0000"),
            end_at: match_time("2016-11-11 20:00:00 +0000"),
            missing_timezone: false,
          ),
        )
      end

      it "ignores events with backwards start/end times because who knows what these are" do
        body = <<~ICAL
          BEGIN:VEVENT
          CREATED:20231211T152742Z
          DTEND;TZID=America/Indianapolis:20240122T123000
          DTSTAMP:20231214T143743Z
          DTSTART;TZID=America/Indianapolis:20240122T160000
          EXDATE;TZID=America/Indianapolis:20231218T110000
          EXDATE;TZID=America/Indianapolis:20231220T110000
          EXDATE;TZID=America/Indianapolis:20231225T110000
          LAST-MODIFIED:20231214T143742Z
          RRULE:FREQ=WEEKLY;BYDAY=MO,WE
          SEQUENCE:0
          SUMMARY:Abe Lincoln
          UID:77082075-30B2-4A5D-AB3C-F65F73C1E90E
          END:VEVENT
        ICAL
        expect(sync(body)).to contain_exactly(
          hash_including(compound_identity: "abc-77082075-30B2-4A5D-AB3C-F65F73C1E90E"),
        )
      end

      it "does not project events before the year 1000 since it is likely a misconfiguration" do
        body = <<~ICAL
          BEGIN:VEVENT
          CREATED:20231211T152742Z
          DTEND;TZID=America/Indianapolis:20240122T123000
          DTSTAMP:20231214T143743Z
          DTSTART;TZID=America/Indianapolis:00210122T110000
          EXDATE;TZID=America/Indianapolis:20231218T110000
          EXDATE;TZID=America/Indianapolis:20231220T110000
          EXDATE;TZID=America/Indianapolis:20231225T110000
          LAST-MODIFIED:20231214T143742Z
          RRULE:FREQ=WEEKLY;BYDAY=MO,WE
          SEQUENCE:0
          SUMMARY:Abe Lincoln
          UID:77082075-30B2-4A5D-AB3C-F65F73C1E90E
          END:VEVENT
        ICAL
        expect(sync(body)).to contain_exactly(
          hash_including(compound_identity: "abc-77082075-30B2-4A5D-AB3C-F65F73C1E90E"),
        )
      end

      it "does not project events older than the configured time" do
        body = <<~ICAL
          BEGIN:VEVENT
          CREATED:20231211T152742Z
          DTEND;TZID=America/Indianapolis:19240122T123000
          DTSTAMP:20231214T143743Z
          DTSTART;TZID=America/Indianapolis:19240122T110000
          EXDATE;TZID=America/Indianapolis:20231218T110000
          EXDATE;TZID=America/Indianapolis:20231220T110000
          EXDATE;TZID=America/Indianapolis:20231225T110000
          LAST-MODIFIED:20231214T143742Z
          RRULE:FREQ=WEEKLY;BYDAY=SA
          SEQUENCE:0
          SUMMARY:Abe Lincoln
          UID:77082075-30B2-4A5D-AB3C-F65F73C1E90E
          END:VEVENT
        ICAL
        got = sync(body)
        expect(got.first).to include(compound_identity: "abc-77082075-30B2-4A5D-AB3C-F65F73C1E90E-3962", start_at: match_time("2000-01-01 16:00:00Z"))
        expect(got.last).to include(start_at: be > 1.month.ago)
      end

      it "yields invalid dates as single events" do
        body = <<~ICAL
          BEGIN:VEVENT
          CREATED:20231211T152742Z
          DTEND;TZID=America/Indianapolis:15240122T123000
          DTSTAMP:20231214T143743Z
          DTSTART;TZID=America/Indianapolis:15240122T110000
          EXDATE;TZID=America/Indianapolis:20231218T110000
          EXDATE;TZID=America/Indianapolis:20231220T110000
          EXDATE;TZID=America/Indianapolis:20231225T110000
          LAST-MODIFIED:20231214T143742Z
          RRULE:FREQ=WEEKLY;BYDAY=MO,WE
          SEQUENCE:0
          SUMMARY:Abe Lincoln
          UID:77082075-30B2-4A5D-AB3C-F65F73C1E90E
          END:VEVENT
        ICAL
        expect(sync(body)).to contain_exactly(hash_including(compound_identity: "abc-77082075-30B2-4A5D-AB3C-F65F73C1E90E"))
      end

      describe "IceCube fixes" do
        it "handles BYSETPOS=2" do
          # See https://github.com/ice-cube-ruby/ice_cube/pull/449
          body = <<~ICAL
            BEGIN:VEVENT
            SUMMARY:Bug Person
            UID:c7614cff-3549-4a00-9152-d25cc1fe077d
            DTSTART:20230711T120000Z
            DTEND:20230711T130000Z
            RRULE:FREQ=MONTHLY;BYSETPOS=2;BYDAY=TU;INTERVAL=1;COUNT=4
            END:VEVENT
          ICAL
          expect(sync(body)).to contain_exactly(
            hash_including(start_at: Time.parse("2023-07-11 12:00:00Z"), end_at: Time.parse("2023-07-11 13:00:00Z"), recurring_event_sequence: 0),
            hash_including(start_at: Time.parse("2023-08-08 12:00:00Z"), end_at: Time.parse("2023-08-08 13:00:00Z"), recurring_event_sequence: 1),
            hash_including(start_at: Time.parse("2023-09-12 12:00:00Z"), end_at: Time.parse("2023-09-12 13:00:00Z"), recurring_event_sequence: 2),
            hash_including(start_at: Time.parse("2023-10-10 12:00:00Z"), end_at: Time.parse("2023-10-10 13:00:00Z"), recurring_event_sequence: 3),
          )
        end
      end
    end

    it "handles RRULE with FREQ=WEEKLY and BYMONTHDAY" do
      body = <<~ICS
        BEGIN:VCALENDAR
        BEGIN:VEVENT
        CREATED:20230819T112212Z
        DTEND;VALUE=DATE:20230907
        DTSTAMP:20230819T112238Z
        DTSTART;VALUE=DATE:20230906
        RRULE:FREQ=WEEKLY;UNTIL=20231115;INTERVAL=2;BYMONTHDAY=4
        SEQUENCE:0
        X-Comment:BYMONTHDAY with FREQ=WEEKLY makes no sense,
          Apple just seems to use every-2-weeks,
          so that's what we'll do here.
        SUMMARY:Circles
        UID:bymonthday-with-freq-weekly
        END:VEVENT
        BEGIN:VEVENT
        CREATED:20230819T112212Z
        DTEND;VALUE=DATE:20230907
        DTSTAMP:20230819T112238Z
        DTSTART;VALUE=DATE:20230906
        RRULE:FREQ=WEEKLY;UNTIL=20231001;BYMONTHDAY=4,26,5;INTERVAL=2
        SEQUENCE:0
        X-Comment:Same as above but with multiple BYMONTHDAY
        SUMMARY:Circles
        UID:multibymonthday-with-freq-weekly
        END:VEVENT
        END:VCALENDAR
      ICS
      req = stub_request(:get, "https://feed.me").
        and_return(status: 200, headers: {"Content-Type" => "text/calendar"}, body:)
      row = insert_calendar_row(ics_url: "https://feed.me", external_id: "abc")
      svc.sync_row(row)
      expect(req).to have_been_made
      expect(event_svc.admin_dataset(&:all)).to contain_exactly(
        include(uid: "bymonthday-with-freq-weekly-0", start_date: Date.new(2023, 9, 6)),
        include(uid: "bymonthday-with-freq-weekly-1", start_date: Date.new(2023, 9, 20)),
        include(uid: "bymonthday-with-freq-weekly-2", start_date: Date.new(2023, 10, 4)),
        include(uid: "bymonthday-with-freq-weekly-3", start_date: Date.new(2023, 10, 18)),
        include(uid: "bymonthday-with-freq-weekly-4", start_date: Date.new(2023, 11, 1)),
        include(uid: "bymonthday-with-freq-weekly-5", start_date: Date.new(2023, 11, 15)),
        include(uid: "multibymonthday-with-freq-weekly-0", start_date: Date.new(2023, 9, 6)),
        include(uid: "multibymonthday-with-freq-weekly-1", start_date: Date.new(2023, 9, 20)),
      )
    end

    it "does not get caught in an endless loop for impossible rrules" do
      body = <<~ICAL
        BEGIN:VCALENDAR
        BEGIN:VEVENT
        CREATED:20220106T215154Z
        DTEND;TZID=America/Los_Angeles:20220112T210000
        DTSTAMP:20220113T033503Z
        DTSTART;TZID=America/Los_Angeles:20220112T200000
        RRULE:FREQ=MONTHLY;BYDAY=2WE;BYSETPOS=2
        SEQUENCE:0
        SUMMARY:High Council Meeting
        UID:82F63A35-0D63-46DB-B06A-B2F95D9BE8E0
        END:VEVENT
        END:VCALENDAR
      ICAL
      # BYSETPOS=2 means 'second occurrence' and BYDAY=2WE means 'second wednesday'.
      # Since there is no month with multiple second wednesdays, this cannot occur.
      req = stub_request(:get, "https://feed.me").
        and_return(status: 200, headers: {"Content-Type" => "text/calendar"}, body:)
      row = insert_calendar_row(ics_url: "https://feed.me", external_id: "abc")
      svc.sync_row(row)
      expect(req).to have_been_made
      expect(event_svc.admin_dataset(&:all)).to be_empty
    end

    it "backs off if the table should avoid writes" do
      Sequel.connect(sint.organization.admin_connection_url) do |db|
        db.transaction do
          db << "LOCK TABLE #{event_sint.table_name}"
          row = insert_calendar_row(ics_url: "https://feed.me", external_id: "abc")
          expect do
            svc.sync_row(row)
          end.to raise_error(Amigo::Retry::Retry)
        end
      end
    end

    it "skips the job if the row has recently been synced, unless force: true" do
      body = <<~ICAL
        BEGIN:VEVENT
        SUMMARY:Abraham Lincoln
        UID:c7614cff-3549-4a00-9152-d25cc1fe077d
        DTSTART:20080212
        DTEND:20080213
        DTSTAMP:20150421T141403
        END:VEVENT
      ICAL
      row = insert_calendar_row(ics_url: "https://feed.me", external_id: "abc", last_synced_at: 2.hours.ago)
      svc.sync_row(row)
      expect(event_svc.admin_dataset(&:all)).to be_empty

      req = stub_request(:get, "https://feed.me").
        and_return(status: 200, headers: {"Content-Type" => "text/calendar"}, body:)
      svc.sync_row(row, force: true)
      expect(req).to have_been_made
      expect(event_svc.admin_dataset(&:all)).to have_length(1)
    end

    describe "with a proxy configured", reset_configuration: Webhookdb::Icalendar do
      before(:each) do
        Webhookdb::Icalendar.proxy_url = "https://icalproxy.webhookdb.com" + (rand < 0.5 ? "" : "/")
      end

      it "calls the proxy server" do
        req = stub_request(:get, "https://icalproxy.webhookdb.com/?url=https://feed.me").
          and_return(
            status: 200,
            headers: {"Content-Type" => "text/calendar"},
            body: "BEGIN:VCALENDAR\nEND:VCALENDAR",
          )
        row = insert_calendar_row(ics_url: "https://feed.me", external_id: "abc")
        svc.sync_row(row)
        expect(req).to have_been_made
      end

      it "sets the authorization header if an api key is configured" do
        Webhookdb::Icalendar.proxy_api_key = "sekret"

        req = stub_request(:get, "https://icalproxy.webhookdb.com/?url=https://feed.me").
          with(headers: {"Authorization" => "Apikey sekret"}).
          and_return(
            status: 200,
            headers: {"Content-Type" => "text/calendar"},
            body: "BEGIN:VCALENDAR\nEND:VCALENDAR",
          )
        row = insert_calendar_row(ics_url: "https://feed.me", external_id: "abc")
        svc.sync_row(row)
        expect(req).to have_been_made
      end

      it "does not skip the sync even if the row has been recently modified" do
        body = <<~ICAL
          BEGIN:VEVENT
          SUMMARY:Abraham Lincoln
          UID:c7614cff-3549-4a00-9152-d25cc1fe077d
          DTSTART:20080212
          DTEND:20080213
          DTSTAMP:20150421T141403
          END:VEVENT
        ICAL
        row = insert_calendar_row(ics_url: "https://feed.me", external_id: "abc", last_synced_at: 1.minute.ago)
        req = stub_request(:get, "https://icalproxy.webhookdb.com/?url=https://feed.me").
          and_return(status: 200, headers: {"Content-Type" => "text/calendar"}, body:)
        svc.sync_row(row)
        expect(req).to have_been_made
        expect(event_svc.admin_dataset(&:all)).to have_length(1)
      end
    end
  end

  # Based on https://github.com/icalendar/icalendar/blob/main/spec/parser_spec.rb
  describe "icalendar parser tests" do
    let(:source) { File.open(Webhookdb::SpecHelpers::TEST_DATA_DIR + "icalendar" + fn) }
    let(:replicator) { described_class.new(nil) }
    let(:upserter) { described_class::Upserter.new(replicator, "1", now: Time.now) }
    let(:headers) { {} }

    def feed_events
      arr = []
      ep = described_class::EventProcessor.new(io: source, encoding: "utf-8", upserter:, headers:)
      ep.each_feed_event { |a| arr << a }
      arr
    end

    def all_events
      arr = []
      pr = described_class::EventProcessor.new(io: source, encoding: "utf-8", upserter:, headers:)
      pr.each_feed_event do |a|
        pr.each_projected_event(a) do |b|
          arr << b
        end
      end
      arr
    end

    describe "single_event.ics" do
      let(:fn) { "single_event.ics" }

      it "returns an array of calendars" do
        parsed = feed_events
        expect(parsed).to contain_exactly(
          {
            "DTSTAMP" => {"v" => "20050118T211523Z"},
            "UID" => {"v" => "bsuidfortestabc123"},
            "DTSTART" => {"v" => "20050120T170000", "TZID" => "US-Mountain"},
            "DTEND" => {"v" => "20050120T184500", "TZID" => "US-Mountain"},
            "CLASS" => {"v" => "PRIVATE"},
            "GEO" => {"v" => "37.386013;-122.0829322"},
            "ORGANIZER" => {"v" => "mailto:joebob@random.net", "CN" => "Joe Bob: Magician"},
            "PRIORITY" => {"v" => "2"},
            "SUMMARY" => {"v" => "This is a really long summary to test the method of unfolding lines\\, so I'm just going to make it a whole bunch of lines. With a twist: a \"ö\" takes up multiple bytes\\, and should be wrapped to the next line."},
            "ATTACH" => [{"v" => "http://bush.sucks.org/impeach/him.rhtml"}, {"v" => "http://corporations-dominate.existence.net/why.rhtml"}],
            "RDATE" => [{"v" => "20050121T170000,20050122T170000", "TZID" => "US-Mountain"}],
            "X-TEST-COMPONENT" => {"v" => "Shouldn't double double quotes", "QTEST" => "Hello, World"},
          },
        )
      end
    end

    describe "with busted, incorrect encoding" do
      # This was generated with the following:
      # iconv -f utf-8 -t iso-8859-1 < spec/data/icalendar/single_event.ics > spec/data/icalendar/single_event_wrong_encoding.ics
      # See code for explanation.
      let(:fn) { "single_event_wrong_encoding.ics" }

      it "forces encoding to utf8" do
        parsed = feed_events
        expect(parsed).to contain_exactly(
          include("UID" => {"v" => "bsuidfortestabc123"}),
        )
      end
    end

    describe "event.ics" do
      let(:fn) { "event.ics" }

      it "returns an array of events" do
        parsed = feed_events
        expect(parsed).to contain_exactly(
          {
            "DTSTAMP" => {"v" => "20050118T211523Z"},
            "UID" => {"v" => "bsuidfortestabc123"},
            "DTSTART" => {"v" => "20050120T170000", "TZID" => "US-Mountain"},
            "DTEND" => {"v" => "20050120T184500", "TZID" => "US-Mountain"},
            "CLASS" => {"v" => "PRIVATE"},
            "GEO" => {"v" => "37.386013;-122.0829322"},
            "ORGANIZER" => {"v" => "mailto:joebob@random.net"},
            "PRIORITY" => {"v" => "2"},
            "SUMMARY" => {"v" => "This is a really long summary to test the method of unfolding lines\\, so I'm just going to make it a whole bunch of lines."},
            "ATTACH" => [{"v" => "http://bush.sucks.org/impeach/him.rhtml"}, {"v" => "http://corporations-dominate.existence.net/why.rhtml"}],
            "RDATE" => [{"v" => "20050121T170000,20050122T170000", "TZID" => "US-Mountain"}],
            "X-TEST-COMPONENT" => {"v" => "Shouldn't double double quotes", "QTEST" => "Hello, World"},
          },
        )
      end
    end

    describe "events.ics" do
      let(:fn) { "two_events.ics" }

      it "returns an array of events" do
        parsed = feed_events
        expect(parsed).to contain_exactly(
          hash_including("UID" => {"v" => "bsuidfortestabc123"}),
          {
            "DTSTAMP" => {"v" => "20110118T211523Z"},
            "UID" => {"v" => "uid-1234-uid-4321"},
            "DTSTART" => {"v" => "20110120T170000", "TZID" => "US-Mountain"},
            "DTEND" => {"v" => "20110120T184500", "TZID" => "US-Mountain"},
            "CLASS" => {"v" => "PRIVATE"},
            "GEO" => {"v" => "37.386013;-122.0829322"},
            "ORGANIZER" => {"v" => "mailto:jmera@jmera.human"},
            "PRIORITY" => {"v" => "2"},
            "SUMMARY" => {"v" => "This is a very short summary."},
            "RDATE" => [{"v" => "20110121T170000,20110122T170000", "TZID" => "US-Mountain"}],
          },
        )
      end
    end

    describe "tzid_search.ics" do
      let(:fn) { "tzid_search.ics" }

      it "correctly sets the weird tzid" do
        parsed = feed_events
        expect(parsed).to contain_exactly(
          hash_including(
            "DTEND" => {"v" => "20180104T130000", "TZID" => "(GMT-05:00) Eastern Time (US & Canada)"},
            "RRULE" => {"v" => "FREQ=WEEKLY;INTERVAL=1"},
            "SUMMARY" => {"v" => "Recurring on Wed"},
            "DTSTART" => {"v" => "20180104T100000", "TZID" => "(GMT-05:00) Eastern Time (US & Canada)"},
            "DTSTAMP" => {"v" => "20120104T231637Z"},
          ),
        )
      end
    end

    describe "missing_required.ics" do
      let(:fn) { "missing_required.ics" }

      it "skips and warns about invalid items" do
        logs = capture_logs_from(replicator.logger, level: :warn, formatter: :json) do
          parsed = feed_events
          expect(parsed).to contain_exactly(
            hash_including("SUMMARY" => {"v" => "Missing DTSTAMP"}),
            hash_including("SUMMARY" => {"v" => "Missing nothing"}),
          )
        end
        expect(logs).to contain_exactly(
          include_json(
            level: "warn",
            name: "Webhookdb::Replicator::IcalendarCalendarV1",
            message: "invalid_vevent_hash",
            context: {
              vevent_uids: ["4BCDDF02-458B-4D52-BC87-86ED43B0BF22", "[missing]", "ev1"],
            },
          ),
        )
      end
    end

    describe "#parse with bad line" do
      let(:fn) { "single_event_bad_line.ics" }

      it "uses nil" do
        parsed = feed_events
        expect(parsed).to contain_exactly(
          hash_including(
            "UID" => {"v" => "bsuidfortestabc123"},
            "X-NO-VALUE" => {"v" => nil},
          ),
        )
      end
    end

    describe "missing date value parameter" do
      let(:fn) { "single_event_bad_dtstart.ics" }

      it "falls back to date type for dtstart" do
        parsed = feed_events
        expect(parsed).to contain_exactly(hash_including("DTSTART" => {"v" => "20050120"}))
      end
    end

    describe "with an invalid bymonthyear/day/frequency combination" do
      let(:fn) { "invalid_bymonthyearday.ics" }

      it "returns an array of calendars" do
        # Because we project '5 years' into the future, we can end up with more than 36 events at times
        # (3102AFB1-1FE8-49A1-BBB2-20965DFD44C9-30 is the extra event).
        # Use Timecop.travel('2024-08-10') to see 36,
        # Timecop.travel('2024-08-16') to see 37,
        # Timecop.travel('2024-12-03') to see 38.
        # Timecop.travel('2025-12-03') to see 39.
        # Rather than having a flaky or imprecise spec, we use timecop to get a consistent result.
        parsed = Timecop.travel(Date.new(2024, 8, 1)) { all_events }
        expect(parsed).to have_length(36)
        expect(parsed).to include(
          hash_including("DTSTART" => {"v" => "20220514"}),
          hash_including("DTSTART" => {"v" => "20220814"}),
          hash_including("DTSTART" => {"v" => "20221114"}),
          hash_including("DTSTART" => {"v" => "20210814"}),
          hash_including("DTSTART" => {"v" => "20211114"}),
          hash_including("DTSTART" => {"v" => "20220214"}),
        )
      end
    end
  end

  describe "feed_changed?" do
    before(:each) do
      org.prepare_database_connections
      svc.create_table
    end

    after(:each) do
      org.remove_related_database
    end

    let(:body) { <<~ICAL }
      BEGIN:VCALENDAR
      END:VCALENDAR
    ICAL
    let(:content_length) { body.size.to_s }
    let(:content_type) { "text/calendar" }

    it "is false if the content headers and feed hash match the previous sync" do
      req = stub_request(:get, "https://feed.me").
        and_return(
          status: 200,
          headers: {"Content-Type" => content_type, "Content-Length" => content_length},
          body:,
        )
      row = insert_calendar_row(
        ics_url: "https://feed.me",
        external_id: "abc",
        last_fetch_context: {
          hash: Digest::MD5.hexdigest(body),
          content_type:,
          content_length:,
        }.to_json,
      )
      expect(svc).to_not be_feed_changed(row)
      expect(req).to have_been_made
    end

    it "is false if the server returns a 304" do
      req = stub_request(:get, "https://feed.me").
        with(headers: {"If-None-Match" => "somevalue"}).
        and_return(status: 304)
      row = insert_calendar_row(
        ics_url: "https://feed.me",
        external_id: "abc",
        last_fetch_context: {
          etag: "somevalue",
        }.to_json,
      )
      expect(svc).to_not be_feed_changed(row)
      expect(req).to have_been_made
    end

    it "is true if the body has a different hash" do
      req = stub_request(:get, "https://feed.me").
        and_return(
          status: 200,
          headers: {"Content-Type" => content_type, "Content-Length" => content_length},
          body:,
        )
      row = insert_calendar_row(
        ics_url: "https://feed.me",
        external_id: "abc",
        last_fetch_context: {
          hash: "abc",
          content_type:,
          content_length:,
        }.to_json,
      )
      expect(svc).to be_feed_changed(row)
      expect(req).to have_been_made
    end

    it "is true if the content type is different" do
      req = stub_request(:get, "https://feed.me").
        and_return(
          status: 200,
          headers: {"Content-Type" => content_type, "Content-Length" => content_length},
          body:,
        )
      row = insert_calendar_row(
        ics_url: "https://feed.me",
        external_id: "abc",
        last_fetch_context: {
          hash: Digest::MD5.hexdigest(body),
          content_type: "text/calendar; charset=utf-8",
          content_length:,
        }.to_json,
      )
      expect(svc).to be_feed_changed(row)
      expect(req).to have_been_made
    end

    it "is true if the content length is different" do
      req = stub_request(:get, "https://feed.me").
        and_return(
          status: 200,
          headers: {"Content-Type" => content_type, "Content-Length" => content_length},
          body:,
        )
      row = insert_calendar_row(
        ics_url: "https://feed.me",
        external_id: "abc",
        last_fetch_context: {
          hash: "abc",
          content_type:,
          content_length: "10",
        }.to_json,
      )
      expect(svc).to be_feed_changed(row)
      expect(req).to have_been_made
    end

    it "is true if the content length is nil" do
      req = stub_request(:get, "https://feed.me").
        and_return(
          status: 200,
          headers: {"Content-Type" => content_type},
          body:,
        )
      row = insert_calendar_row(
        ics_url: "https://feed.me",
        external_id: "abc",
        last_fetch_context: {
          hash: "abc",
          content_type:,
          content_length: nil,
        }.to_json,
      )
      expect(svc).to be_feed_changed(row)
      expect(req).to have_been_made
    end

    it "is true (and does not fetch) with a nil fetch context" do
      row = insert_calendar_row(
        ics_url: "https://feed.me",
        external_id: "abc",
      )
      expect(svc).to be_feed_changed(row)
    end

    it "is true (and does not fetch) with an empty fetch context" do
      row = insert_calendar_row(
        ics_url: "https://feed.me",
        external_id: "abc",
        last_fetch_context: {}.to_json,
      )
      expect(svc).to be_feed_changed(row)
    end

    it "is true if the fetch errors" do
      req = stub_request(:get, "https://feed.me").
        and_raise(RuntimeError)
      row = insert_calendar_row(
        ics_url: "https://feed.me",
        external_id: "abc",
        last_fetch_context: {
          hash: "abc",
          content_type:,
          content_length:,
        }.to_json,
      )
      expect(svc).to be_feed_changed(row)
      expect(req).to have_been_made
    end
  end
end
# rubocop:enable Layout/LineLength
