# frozen_string_literal: true

require "support/shared_examples_for_replicators"

RSpec.describe Webhookdb::Replicator::IcalendarEventV1Partitioned, :db do
  let(:org) { Webhookdb::Fixtures.organization.create }
  let(:fac) { Webhookdb::Fixtures.service_integration(organization: org) }
  let(:calendar_sint) { fac.create(service_name: "icalendar_calendar_v1") }
  let(:calendar_svc) { calendar_sint.replicator }
  let(:sint) { fac.depending_on(calendar_sint).create(service_name: "icalendar_event_v1_partitioned").refresh }
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
end
