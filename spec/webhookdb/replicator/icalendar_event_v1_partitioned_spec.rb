# frozen_string_literal: true

require "support/shared_examples_for_replicators"

RSpec.describe Webhookdb::Replicator::IcalendarEventV1Partitioned, :db do
  let(:org) { Webhookdb::Fixtures.organization.create }
  let(:fac) { Webhookdb::Fixtures.service_integration(organization: org) }
  let(:calendar_sint) { fac.create(service_name: "icalendar_calendar_v1") }
  let(:calendar_svc) { calendar_sint.replicator }
  let(:sint) do
    fac.depending_on(calendar_sint).create(service_name: "icalendar_event_v1_partitioned", partition_value: 200)
  end
  let(:svc) { sint.replicator }

  it_behaves_like "a replicator that supports hash partitioning" do
    def body(i)
      s = <<~ICAL
        BEGIN:VEVENT
        DTSTART:20200220T170000Z
        DTEND:20190820T190000Z
        UID:79396C44-9EA7-4EF0-A99F-5EFCE7764CFE
        END:VEVENT
      ICAL
      h = described_class.vevent_to_hash(s.lines)
      h["calendar_external_id"] = i.to_s
      h["row_updated_at"] = Time.now.iso8601
      return h
    end
  end

  def insert_calendar_row(**more)
    calendar_svc.admin_dataset do |ds|
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

  describe "sync_row" do
    before(:each) do
      org.prepare_database_connections
      calendar_svc.create_table
      svc.create_table
    end

    after(:each) do
      org.remove_related_database
    end

    it "upserts each vevent in the url, and stores meta about the fetch" do
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
        DTSTART:20080212
        DTEND:20080213
        DTSTAMP:20150421T141403
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
      calendar_svc.sync_row(row)
      calendar_svc.sync_row(row)
      expect(req).to have_been_made.times(2)
      expect(calendar_svc.admin_dataset(&:all)).to contain_exactly(include(last_synced_at: match_time(:now)))
      expect(svc.admin_dataset(&:all)).to contain_exactly(
        include(
          calendar_external_id: "abc",
          compound_identity: "abc-c7614cff-3549-4a00-9152-d25cc1fe077d",
          external_calendar_hash: -2_146_104_957,
        ),
      )
    end
  end
end
