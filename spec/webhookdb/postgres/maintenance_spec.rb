# frozen_string_literal: true

require "webhookdb/postgres/maintenance"

RSpec.describe Webhookdb::Postgres::Maintenance, :db do
  let(:org) { Webhookdb::Fixtures.organization.with_urls(admin: ENV.fetch("DATABASE_URL")).create }
  let(:sint) { Webhookdb::Fixtures.service_integration(organization: org).create }

  it "errors for commands that cannot find a superuser url" do
    org.update(admin_connection_url_raw: Faker::Webhookdb.pg_connection)
    expect do
      described_class::Repack.new(sint).command_strings
    end.to raise_error(Webhookdb::InvalidPrecondition, /cannot find superuser/)
  end

  it "can generate a pg_repack command" do
    # rubocop:disable Layout/LineLength
    r = described_class::Repack.new(sint)
    expect(r.command_strings).to contain_exactly(
      start_with("PGPASSWORD=webhookdb psql --no-password -U webhookdb"),
      start_with("docker run -e PGPASSWORD=webhookdb -it --rm hartmutcouk/pg-repack-docker:1.4.7 pg_repack --no-password -U webhookdb"),
    )
    # rubocop:enable Layout/LineLength
  end

  it "can generate an approximate count query" do
    r = described_class::Count.new(sint)
    expect(r.query).to include("reltuples AS estimate")
  end

  it "can generate a query to summarize all tables for an org" do
    r = described_class::Tables.new(sint)
    expect(r.query).to include('pg_size_pretty(pg_total_relation_size(C .oid)) as "size"')
  end
end
