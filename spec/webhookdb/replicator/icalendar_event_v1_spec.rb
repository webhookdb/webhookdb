# frozen_string_literal: true

require "support/shared_examples_for_replicators"

RSpec.describe Webhookdb::Replicator::IcalendarEventV1, :db do
  let(:org) { Webhookdb::Fixtures.organization.create }
  let(:fac) { Webhookdb::Fixtures.service_integration(organization: org) }
  let(:calendar_sint) { fac.create(service_name: "icalendar_calendar_v1") }
  let(:calendar_svc) { calendar_sint.replicator }
  let(:sint) { fac.depending_on(calendar_sint).create(service_name: "icalendar_event_v1").refresh }
  let(:svc) { sint.replicator }
  let(:calendar_external_id) { "123" }
  let(:ics_url) { "https://spec.test" }

  it_behaves_like "a replicator", supports_row_diff: false do
    let(:body) do
      s = <<~ICAL
        BEGIN:VEVENT
        DTSTART:20200220T170000Z
        DTEND:20190820T190000Z
        UID:79396C44-9EA7-4EF0-A99F-5EFCE7764CFE
        END:VEVENT
      ICAL
      h = described_class.vevent_to_hash(s.lines)
      h["calendar_external_id"] = "123"
      h["row_updated_at"] = Time.now.iso8601
      h
    end
    let(:expected_row) do
      include(
        :pk,
        calendar_external_id: "123",
        compound_identity: "123-79396C44-9EA7-4EF0-A99F-5EFCE7764CFE",
        data: include("DTEND").and(not_include("row_updated_at")),
        start_at: match_time("2020-02-20 17:00:00Z"),
        uid: "79396C44-9EA7-4EF0-A99F-5EFCE7764CFE",
      )
    end
  end

  it_behaves_like "a replicator dependent on another", "icalendar_calendar_v1" do
    let(:no_dependencies_message) { "" }
  end

  it_behaves_like "a replicator with a custom backfill not supported message"

  describe "upsert" do
    def upsert(s)
      h = described_class.vevent_to_hash(s.lines)
      h["calendar_external_id"] = "123"
      h["row_updated_at"] = Time.now.iso8601
      return svc.upsert_webhook_body(h, upsert: false)
    end

    it "does a basic upsert with defaults" do
      s = <<~ICAL
        BEGIN:VEVENT
        DTSTART:20200220T170000Z
        DTEND:20190820T190000Z
        UID:79396C44-9EA7-4EF0-A99F-5EFCE7764CFE
        END:VEVENT
      ICAL
      expect(upsert(s)).to include(
        calendar_external_id: "123",
        compound_identity: "123-79396C44-9EA7-4EF0-A99F-5EFCE7764CFE",
        data: not_include("calendar_external_id"),
        last_modified_at: match_time(:now),
        row_updated_at: match_time(:now),
        uid: "79396C44-9EA7-4EF0-A99F-5EFCE7764CFE",
      )
    end

    it "can handle datetimes with timezones" do
      s = <<~ICAL
        BEGIN:VEVENT
        DTSTART:20200220T170000Z
        DTEND:20190820T190000Z
        UID:79396C44-9EA7-4EF0-A99F-5EFCE7764CFE
        END:VEVENT
      ICAL
      expect(upsert(s)).to include(
        start_at: match_time("20200220T170000Z"),
        end_at: match_time("20190820T190000Z"),
        start_date: nil,
        end_date: nil,
      )
    end

    it "can handle dates" do
      s = <<~ICAL
        BEGIN:VEVENT
        DTSTART:20200228
        DTEND:20190820
        UID:79396C44-9EA7-4EF0-A99F-5EFCE7764CFE
        END:VEVENT
      ICAL
      expect(upsert(s)).to include(
        start_at: nil,
        end_at: nil,
        start_date: Date.new(2020, 2, 28),
        end_date: Date.new(2019, 8, 20),
      )
    end

    it "sets a DTSTART date without a DTEND as one day" do
      s = <<~ICAL
        BEGIN:VEVENT
        DTSTART:20190228
        UID:79396C44-9EA7-4EF0-A99F-5EFCE7764CFE
        END:VEVENT
      ICAL
      expect(upsert(s)).to include(
        start_at: nil,
        end_at: nil,
        start_date: Date.new(2019, 2, 28),
        end_date: Date.new(2019, 3, 1),
      )
    end

    it "sets a DTSTART datetime without a DTEND to end at the start time" do
      s = <<~ICAL
        BEGIN:VEVENT
        DTSTART:20200220T170000Z
        UID:79396C44-9EA7-4EF0-A99F-5EFCE7764CFE
        END:VEVENT
      ICAL
      expect(upsert(s)).to include(
        start_at: match_time("20200220T170000Z"),
        end_at: match_time("20200220T170000Z"),
      )
    end

    it "sets a DTSTART date using the DURATION if there is no DTEND" do
      s = <<~ICAL
        BEGIN:VEVENT
        DTSTART:20190215
        DURATION:P3D
        UID:79396C44-9EA7-4EF0-A99F-5EFCE7764CFE
        END:VEVENT
      ICAL
      expect(upsert(s)).to include(
        start_at: nil,
        end_at: nil,
        start_date: Date.new(2019, 2, 15),
        end_date: Date.new(2019, 2, 18),
      )
    end

    it "sets a DTSTART datetime using the DURATION if there is no DTEND" do
      s = <<~ICAL
        BEGIN:VEVENT
        DTSTART:20200220T170000Z
        DURATION:P3DT2H5M
        UID:79396C44-9EA7-4EF0-A99F-5EFCE7764CFE
        END:VEVENT
      ICAL
      expect(upsert(s)).to include(
        start_at: match_time("20200220T170000Z"),
        end_at: match_time("20200223T190500Z"),
      )
    end

    it "prefers DTEND over DURATION" do
      s = <<~ICAL
        BEGIN:VEVENT
        DTSTART:20180215
        DURATION:P5D
        DTEND:20180217
        UID:79396C44-9EA7-4EF0-A99F-5EFCE7764CFE
        END:VEVENT
      ICAL
      expect(upsert(s)).to include(
        start_at: nil,
        end_at: nil,
        start_date: Date.new(2018, 2, 15),
        end_date: Date.new(2018, 2, 17),
      )
    end

    it "can handle datetimes with local timezones" do
      s = <<~ICAL
        BEGIN:VEVENT
        DTSTART;TZID=US-Eastern:20200520T170000
        DTEND;TZID=America/Los_Angeles:20190820T190000
        UID:79396C44-9EA7-4EF0-A99F-5EFCE7764CFE
        END:VEVENT
      ICAL
      expect(upsert(s)).to include(
        start_at: match_time("2020-05-20T17:00:00-0400"),
        end_at: match_time("2019-08-20T19:00:00-0700"),
        start_date: nil,
        end_date: nil,
      )
    end

    it "can handle weird TZ ids" do
      s = <<~ICAL
        BEGIN:VEVENT
        DTSTART;TZID=GMT-0400:20200520T170000
        DTEND;TZID=UTC+0500:20190820T190000
        UID:79396C44-9EA7-4EF0-A99F-5EFCE7764CFE
        END:VEVENT
      ICAL
      expect(upsert(s)).to include(
        start_at: match_time("2020-05-20T17:00:00-0400"),
        end_at: match_time("2019-08-20T19:00:00+0500"),
        start_date: nil,
        end_date: nil,
      )
    end

    it "can handle outlook TZ ids" do
      s = <<~ICAL
        BEGIN:VEVENT
        DTSTART;TZID=Eastern Standard Time:20230616T220000
        DTEND;TZID=Eastern Standard Time:20230616T223000
        UID:79396C44-9EA7-4EF0-A99F-5EFCE7764CFE
        END:VEVENT
      ICAL
      expect(upsert(s)).to include(
        start_at: match_time("2023-06-16 22:00:00-0400"),
        end_at: match_time("2023-06-16 22:30:00-0400"),
        start_date: nil,
        end_date: nil,
      )
    end

    it "can handle invalid tzids" do
      s = <<~ICAL
        BEGIN:VEVENT
        DTSTART;TZID=Invalid Time:20230616T220000
        DTEND;TZID=Invalid Time:20230616T223000
        UID:79396C44-9EA7-4EF0-A99F-5EFCE7764CFE
        END:VEVENT
      ICAL
      expect(upsert(s)).to include(
        start_at: match_time("2023-06-16 22:00:00+0000"),
        end_at: match_time("2023-06-16 22:30:00+0000"),
      )
    end

    it "parses other fields" do
      s = <<~ICAL
        BEGIN:VEVENT
        DTSTART:20200220T170000Z
        DTEND:20190820T190000Z
        UID:79396C44-9EA7-4EF0-A99F-5EFCE7764CFE
        LAST-MODIFIED:20230218T223614Z
        CREATED:20210218T223614Z
        STATUS:CONFIRMED
        CATEGORIES:x,y
        PRIORITY:9
        GEO:45.55;-120.99
        CLASS:PRIVATE
        END:VEVENT
      ICAL
      expect(upsert(s)).to include(
        categories: contain_exactly("x", "y"),
        classification: "PRIVATE",
        created_at: match_time("2021-02-18 22:36:14Z"),
        geo_lat: 45.55,
        geo_lng: -120.99,
        last_modified_at: match_time("2023-02-18 22:36:14Z"),
        priority: 9,
        status: "CONFIRMED",
      )
    end
  end

  describe "::vevent_to_hash" do
    it "parses as expected" do
      s = <<~ICAL
        BEGIN:VEVENT
        DTSTART;TZID=America/Los_Angeles:20200220T170000
        DTEND:20190820T190000Z
        DTSTAMP:20230426T152258Z
        ORGANIZER;CN=chez@helloyu.com:mailto:chez@helloyu.com
        UID:79396C44-9EA7-4EF0-A99F-5EFCE7764CFE
        ATTENDEE;CUTYPE=INDIVIDUAL;ROLE=REQ-PARTICIPANT;PARTSTAT=ACCEPTED;CN=chez@h
         elloyu.com;X-NUM-GUESTS=0:mailto:chez@helloyu.com
        ATTENDEE;CUTYPE=INDIVIDUAL;ROLE=REQ-PARTICIPANT;PARTSTAT=ACCEPTED;CN=rob.ga
         lanakis@gmail.com;X-NUM-GUESTS=0:mailto:rob.galanakis@gmail.com
        CREATED:20190813T175204Z
        DESCRIPTION:
        LAST-MODIFIED:20230218T223450Z
        LOCATION:Good Coffee\\n4747 SE Division St\\nPortland OR 97206-1509
        SEQUENCE:1
        STATUS:CONFIRMED
        SUMMARY:Rob/Chez coffee
        TRANSP:OPAQUE
        END:VEVENT
      ICAL
      expect(described_class.vevent_to_hash(s.split("\n"))).to eq(
        {
          "DTSTART" => {"v" => "20200220T170000", "TZID" => "America/Los_Angeles"},
          "DTEND" => {"v" => "20190820T190000Z"},
          "DTSTAMP" => {"v" => "20230426T152258Z"},
          "ORGANIZER" => {"CN" => "chez@helloyu.com", "v" => "mailto:chez@helloyu.com"},
          "UID" => {"v" => "79396C44-9EA7-4EF0-A99F-5EFCE7764CFE"},
          "ATTENDEE" => [
            {"v" => "mailto:chez@helloyu.com", "CUTYPE" => "INDIVIDUAL", "ROLE" => "REQ-PARTICIPANT",
             "PARTSTAT" => "ACCEPTED", "CN" => "chez@helloyu.com", "X-NUM-GUESTS" => "0",},
            {"v" => "mailto:rob.galanakis@gmail.com", "CUTYPE" => "INDIVIDUAL", "ROLE" => "REQ-PARTICIPANT",
             "PARTSTAT" => "ACCEPTED", "CN" => "rob.galanakis@gmail.com", "X-NUM-GUESTS" => "0",},
          ],
          "CREATED" => {"v" => "20190813T175204Z"},
          "DESCRIPTION" => {"v" => ""},
          "LAST-MODIFIED" => {"v" => "20230218T223450Z"},
          "LOCATION" => {"v" => "Good Coffee\n4747 SE Division St\nPortland OR 97206-1509"},
          "SEQUENCE" => {"v" => "1"},
          "STATUS" => {"v" => "CONFIRMED"},
          "SUMMARY" => {"v" => "Rob/Chez coffee"},
          "TRANSP" => {"v" => "OPAQUE"},
        },
      )
    end
  end

  describe "#on_dependency_webhook_upsert" do
    it "noops" do
      expect { svc.on_dependency_webhook_upsert(nil, nil) }.to_not raise_error
    end
  end

  describe "schema" do
    it "uses partial indices for date columns" do
      # Hard code values to avoid flakiness on opaque id length and leftover index name size.
      sint.update(opaque_id: "svi_4rropdhippn7o0o9k966otl5", table_name: "svctable")
      mod = svc.create_table_modification
      # rubocop:disable Layout/LineLength
      expect(mod.transaction_statements).to include(
        "CREATE INDEX IF NOT EXISTS svi_4rropdhippn7o0o9k966otl5_start_at_idx ON public.svctable (start_at) WHERE (\"start_at\" IS NOT NULL)",
        "CREATE INDEX IF NOT EXISTS svi_4rropdhippn7o0o9k966otl5_end_at_idx ON public.svctable (end_at) WHERE (\"end_at\" IS NOT NULL)",
        "CREATE INDEX IF NOT EXISTS svi_4rropdhippn7o0o9k966otl5_start_date_idx ON public.svctable (start_date) WHERE (\"start_date\" IS NOT NULL)",
        "CREATE INDEX IF NOT EXISTS svi_4rropdhippn7o0o9k966otl5_end_date_idx ON public.svctable (end_date) WHERE (\"end_date\" IS NOT NULL)",
        "CREATE INDEX IF NOT EXISTS svi_4rropdhippn7o0o9k966otl5_recurring_event_id_idx ON public.svctable (recurring_event_id) WHERE (\"recurring_event_id\" IS NOT NULL)",
        "CREATE INDEX IF NOT EXISTS svi_4rropdhippn7o0o9k966otl5_50d5d161e2e533574149dd136a9fc8_idx ON public.svctable (calendar_external_id, start_at, end_at) WHERE ((\"status\" IS DISTINCT FROM 'CANCELLED') AND (\"start_at\" IS NOT NULL))",
        "CREATE INDEX IF NOT EXISTS svi_4rropdhippn7o0o9k966otl5_2a46eca5b6e6adca4a315774180a30_idx ON public.svctable (calendar_external_id, start_date, end_date) WHERE ((\"status\" IS DISTINCT FROM 'CANCELLED') AND (\"start_date\" IS NOT NULL))",
      )
      # rubocop:enable Layout/LineLength
    end
  end

  describe "StaleRowDeleter" do
    before(:each) do
      org.prepare_database_connections
      svc.create_table
    end

    after(:each) { org.remove_related_database }

    def upsert(uid, updated, status: "CANCELLED")
      s = <<~ICAL
        BEGIN:VEVENT
        DTSTART:20200220T170000Z
        DTEND:20190820T190000Z
        UID:#{uid}
        STATUS:#{status}
        END:VEVENT
      ICAL
      h = described_class.vevent_to_hash(s.lines)
      h["calendar_external_id"] = "123"
      h["row_updated_at"] = updated.iso8601
      return svc.upsert_webhook_body(h)
    end

    it "deletes stale cancelled events" do
      upsert("recent", 3.days.ago)
      upsert("stale", 40.days.ago)
      upsert("stale_not_cancelled", 40.days.ago, status: "CONFIRMED")
      upsert("too_old", 100.days.ago)
      svc.stale_row_deleter.run
      expect(svc.admin_dataset { |ds| ds.select(:uid).all }).to contain_exactly(
        include(uid: "recent"),
        include(uid: "stale_not_cancelled"),
        include(uid: "too_old"),
      )
    end

    it "can use a nil age cutoff" do
      upsert("recent", 3.days.ago)
      upsert("stale", 40.days.ago)
      upsert("old", 100.days.ago)
      svc.stale_row_deleter.run_initial
      expect(svc.admin_dataset(&:all)).to contain_exactly(
        include(uid: "recent"),
      )
    end

    it "deletes in chunks" do
      upsert("recent", 3.days.ago)
      Array.new(100) { upsert("stale", 40.days.ago) }
      upsert("not_cancelled", 40.days.ago, status: "CONFIRMED")
      svc.stale_row_deleter.run
      expect(svc.admin_dataset(&:all)).to contain_exactly(
        include(uid: "recent"),
        include(uid: "not_cancelled"),
      )
    end
  end
end
