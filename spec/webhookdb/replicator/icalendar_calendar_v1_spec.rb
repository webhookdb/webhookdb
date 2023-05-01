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

  it_behaves_like "a replicator", "icalendar_calendar_v1" do
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
    let(:supports_row_diff) { false }
  end

  it_behaves_like "a replicator with dependents", "icalendar_calendar_v1", "icalendar_event_v1" do
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

      it "responds to `SYNC` requests by upserting and enqueing a sync" do
        expect(Webhookdb::Jobs::IcalendarSync).to receive(:perform_async).
          with(sint.id, "456")
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
            row_updated_at: match_time(updated),
            ics_url: "https://y.z",
          ),
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
    describe "calculate_create_state_machine" do
      it "prompts for the secret" do
        sm = sint.calculate_create_state_machine
        expect(sm).to have_attributes(
          needs_input: true,
          complete: false,
          output: include("about to add support for syncing iCalendar"),
          prompt: include("secret"),
        )
      end

      it "completes if secret is set" do
        sint.webhook_secret = "abc"
        sm = sint.calculate_create_state_machine
        expect(sm).to have_attributes(
          needs_input: false,
          complete: true,
          output: include("All set! Here is the endpoint"),
        )
      end
    end

    describe "calculate_backfill_state_machine" do
      it "uses the create state machine" do
        sm = sint.calculate_backfill_state_machine
        expect(sm).to have_attributes(
          needs_input: true,
          complete: false,
          output: include("add support for syncing iCalendar"),
        )
      end
    end
  end

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

    it "upserts each vevent in the url" do
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
        RRULE:FREQ=YEARLY;INTERVAL=1;BYMONTH=2;BYMONTHDAY=12
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
        and_return(status: 200, headers: {"Content-Type" => "text/calendar"}, body:)
      row = insert_calendar_row(ics_url: "https://feed.me", external_id: "abc")
      svc.sync_row(row)
      expect(svc.admin_dataset(&:first)).to include(last_synced_at: match_time(:now))
      expect(req).to have_been_made
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

    it "noops if there's no event integration" do
      event_sint.destroy
      row = insert_calendar_row(ics_url: "https://feed.me", external_id: "abc")
      svc.sync_row(row)
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
        LAST-MODIFIED:20150421T141403Z
        END:VEVENT
        END:VCALENDAR
      ICAL
      updated1 = v1.gsub("Version1", "Version2")
      updated2 = v1.gsub("Version1", "Version3").gsub("20150421T141403Z", "20160421T141403Z")
      updated3 = v1.gsub("Version1", "Version4").gsub("\nLAST-MODIFIED:20150421T141403Z", "")
      req = stub_request(:get, "https://feed.me").
        and_return(
          {status: 200, headers: {"Content-Type" => "text/calendar"}, body: v1},
          {status: 200, headers: {"Content-Type" => "text/calendar"}, body: updated1},
          {status: 200, headers: {"Content-Type" => "text/calendar"}, body: updated2},
          {status: 200, headers: {"Content-Type" => "text/calendar"}, body: updated3},
        )
      row = insert_calendar_row(ics_url: "https://feed.me", external_id: "abc")
      svc.sync_row(row)
      expect(event_svc.admin_dataset(&:all)).to contain_exactly(
        include(data: hash_including("SUMMARY" => {"v" => "Version1"})),
      )
      svc.sync_row(row)
      expect(event_svc.admin_dataset(&:all)).to contain_exactly(
        include(data: hash_including("SUMMARY" => {"v" => "Version1"})),
      )
      svc.sync_row(row)
      expect(event_svc.admin_dataset(&:all)).to contain_exactly(
        include(data: hash_including("SUMMARY" => {"v" => "Version3"})),
      )
      svc.sync_row(row)
      expect(event_svc.admin_dataset(&:all)).to contain_exactly(
        include(data: hash_including("SUMMARY" => {"v" => "Version4"})),
      )
      expect(req).to have_been_made.times(4)
    end

    it "uses UTC for unregonized timezones" do
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
  end

  # Based on https://github.com/icalendar/icalendar/blob/main/spec/parser_spec.rb
  describe "icalendar parser tests" do
    let(:source) { File.open(Webhookdb::SpecHelpers::TEST_DATA_DIR + "icalendar" + fn) }

    def events
      arr = []
      described_class.each_event(source) { |a| arr << a }
      arr
    end

    context "single_event.ics" do
      let(:fn) { "single_event.ics" }

      it "returns an array of calendars" do
        parsed = events
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
            "ATTACH" => {"v" => "http://corporations-dominate.existence.net/why.rhtml"},
            "RDATE" => {"v" => "20050121T170000,20050122T170000", "TZID" => "US-Mountain"},
            "X-TEST-COMPONENT" => {"v" => "Shouldn't double double quotes", "QTEST" => "Hello, World"},
          },
        )
      end
    end

    context "event.ics" do
      let(:fn) { "event.ics" }

      it "returns an array of events" do
        parsed = events
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
            "ATTACH" => {"v" => "http://corporations-dominate.existence.net/why.rhtml"},
            "RDATE" => {"v" => "20050121T170000,20050122T170000", "TZID" => "US-Mountain"},
            "X-TEST-COMPONENT" => {"v" => "Shouldn't double double quotes", "QTEST" => "Hello, World"},
          },
        )
      end
    end

    context "events.ics" do
      let(:fn) { "two_events.ics" }

      it "returns an array of events" do
        parsed = events
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
            "RDATE" => {"v" => "20110121T170000,20110122T170000", "TZID" => "US-Mountain"},
          },
        )
      end
    end

    context "tzid_search.ics" do
      let(:fn) { "tzid_search.ics" }

      it "correctly sets the weird tzid" do
        parsed = events
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

    describe "#parse with bad line" do
      let(:fn) { "single_event_bad_line.ics" }

      it "uses nil" do
        parsed = events
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
        parsed = events
        expect(parsed).to contain_exactly(hash_including("DTSTART" => {"v" => "20050120"}))
      end
    end
  end
end
# rubocop:enable Layout/LineLength
