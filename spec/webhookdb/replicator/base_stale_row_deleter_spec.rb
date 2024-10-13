# frozen_string_literal: true

RSpec.describe Webhookdb::Replicator::BaseStaleRowDeleter, :db do
  let(:sint) { Webhookdb::Fixtures.service_integration.create(service_name: "fake_stale_row_v1") }
  let(:svc) { sint.replicator }
  let(:org) { sint.organization }

  before(:each) do
    org.prepare_database_connections
    svc.create_table
  end

  after(:each) { org.remove_related_database }

  def upsert(my_id, at, textcol)
    return svc.upsert_webhook_body({my_id:, at:, textcol:}.stringify_keys)
  end

  it "deletes stale rows" do
    upsert("recent", 3.days.ago, "cancelled")
    upsert("stale", 7.days.ago, "cancelled")
    upsert("stale_not_cancelled", 7.days.ago, "confirmed")
    upsert("too_old", 12.days.ago, "cancelled")
    svc.stale_row_deleter.run
    expect(svc.admin_dataset { |ds| ds.select(:my_id).all }).to contain_exactly(
      include(my_id: "recent"),
      include(my_id: "stale_not_cancelled"),
      include(my_id: "too_old"),
    )
  end

  it "can use a nil age cutoff" do
    upsert("recent", 3.days.ago, "cancelled")
    upsert("stale", 7.days.ago, "cancelled")
    upsert("old", 12.days.ago, "cancelled")
    svc.stale_row_deleter.run_initial
    expect(svc.admin_dataset(&:all)).to contain_exactly(
      include(my_id: "recent"),
    )
  end

  it "deletes in chunks (implementation test)" do
    # Create a bunch of rows at the same time to ensure they all get deleted as chunks,
    # to test the 'delete in chunks' behavior.
    upsert("recent", 3.days.ago, "cancelled")
    Array.new(43) { upsert("stale", 7.days.ago, "cancelled") }
    upsert("not_cancelled", 7.days.ago, "confirmed")
    svc.stale_row_deleter.run
    expect(svc.admin_dataset(&:all)).to contain_exactly(
      include(my_id: "recent"),
      include(my_id: "not_cancelled"),
    )
  end

  it "walks the row delete interval in small increments (implementation test)" do
    # Create a spread of rows across and beyond the full time range and make sure they all get deleted,
    # to check the 'incremental time range walking' behavior.
    Timecop.freeze("2020-10-30") do
      at = 4.days.ago.utc
      cutoff = 11.days.ago.utc
      until at < cutoff
        upsert("e-#{at.iso8601}", at, "cancelled")
        at -= 4.hours
      end
      svc.stale_row_deleter.run
    end
    expect(svc.admin_dataset(&:all)).to contain_exactly(
      include(my_id: "e-2020-10-26T07:00:00Z"),
      include(my_id: "e-2020-10-26T03:00:00Z"),
      include(my_id: "e-2020-10-25T23:00:00Z"),
      include(my_id: "e-2020-10-25T19:00:00Z"),
      include(my_id: "e-2020-10-25T15:00:00Z"),
      include(my_id: "e-2020-10-25T11:00:00Z"),
      include(my_id: "e-2020-10-20T03:00:00Z"),
      include(my_id: "e-2020-10-19T23:00:00Z"),
      include(my_id: "e-2020-10-19T19:00:00Z"),
      include(my_id: "e-2020-10-19T15:00:00Z"),
      include(my_id: "e-2020-10-19T11:00:00Z"),
      include(my_id: "e-2020-10-19T07:00:00Z"),
    )
  end

  it "disables and re-enables vacuuming, and runs with seqscan disabled" do
    upsert("e1", Time.now, "confirmed")
    logs = capture_logs_from(Webhookdb.logger, level: :debug, formatter: :json) do
      svc.stale_row_deleter.run
    end
    expect(logs).to have_a_line_matching(
      /"query":"ALTER TABLE public\.#{sint.table_name} SET \(autovacuum_enabled='off'\)"/,
    )
    expect(logs).to have_a_line_matching(
      /"query":"ALTER TABLE public\.#{sint.table_name} SET \(autovacuum_enabled='on'\)"/,
    )
    expect(logs).to have_a_line_matching(
      /SET LOCAL enable_seqscan='off';/,
    )
  end

  it "handles no rows (to delete, or at all)" do
    expect do
      svc.stale_row_deleter.run
      svc.stale_row_deleter.run_initial
      upsert("e1", Time.now, "confirmed")
      svc.stale_row_deleter.run
      svc.stale_row_deleter.run_initial
    end.to_not raise_error
  end
end
