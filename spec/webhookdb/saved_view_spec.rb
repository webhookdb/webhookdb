# frozen_string_literal: true

require "webhookdb/saved_view"

RSpec.describe "Webhookdb::SavedView", :db do
  let(:described_class) { Webhookdb::SavedView }

  it "has appropriate associations" do
    cq = Webhookdb::Fixtures.saved_view.created_by.create
    expect(cq).to have_attributes(
      organization: be_a(Webhookdb::Organization),
      created_by: be_a(Webhookdb::Customer),
    )
  end

  describe ".create_or_replace" do
    let(:org) { Webhookdb::Fixtures.organization.create }

    after(:each) do
      org.remove_related_database
    end

    it "creates a new view" do
      org.prepare_database_connections
      sva = described_class.create_or_replace(organization: org, sql: "SELECT 1 AS x", name: "testview")
      expect(org.saved_views).to contain_exactly(be === sva)
      expect(org.readonly_connection { |c| c[:testview].all }).to eq([{x: 1}])

      svb = described_class.create_or_replace(organization: org, sql: "SELECT 1 AS y", name: "testview2")
      expect(org.saved_views(reload: true)).to contain_exactly(be === sva, be === svb)
      expect(org.readonly_connection { |c| c[:testview2].all }).to eq([{y: 1}])
    end

    it "replaces a view with the same name" do
      org.prepare_database_connections
      sv1 = described_class.create_or_replace(organization: org, sql: "SELECT 1 AS x", name: "testview")
      sv2 = described_class.create_or_replace(organization: org, sql: "SELECT 2 AS x", name: "testview")
      expect(sv2).to be === sv1
      expect(org.saved_views).to contain_exactly(be === sv2)
      expect(org.readonly_connection { |c| c[:testview].all }).to eq([{x: 2}])
    end

    it "escapes/quotes the name" do
      org.prepare_database_connections
      expect do
        described_class.create_or_replace(organization: org, sql: "SELECT 1 AS z", name: "x y")
      end.to_not raise_error
      expect(org.readonly_connection { |c| c.select(Sequel.lit('* FROM "x y"')).all }).to eq([{z: 1}])
    end

    it "errors if the view name is not a valid identifier" do
      expect do
        described_class.create_or_replace(organization: org, sql: "SELECT 1", name: "hi-there")
      end.to raise_error(Webhookdb::DBAdapter::InvalidIdentifier)
    end

    it "errors if the view query cannot run as readonly" do
      org.prepare_database_connections
      expect do
        described_class.create_or_replace(organization: org, sql: "CREATE TABLE xyz(pk TEXT)", name: "testview")
      end.to raise_error(described_class::InvalidQuery, /Queries must be read-only/)
    end
  end

  describe "destroying" do
    let(:org) { Webhookdb::Fixtures.organization.create }

    after(:each) do
      org.remove_related_database
    end

    it "drops the view if it exists" do
      org.prepare_database_connections
      sv = described_class.create_or_replace(organization: org, sql: "SELECT 1 AS x", name: "testview")
      expect(org.readonly_connection { |c| c[:testview].all }).to have_length(1)
      sv.destroy
      expect { org.readonly_connection { |c| c[:testview].all } }.to raise_error(/relation "testview" does not exist/)
    end

    it "noops if the view does not exist" do
      org.prepare_database_connections
      sv = Webhookdb::Fixtures.saved_view.create(organization: org)
      expect { sv.destroy }.to_not raise_error
    end

    it "errors if the view name is not a valid identifier" do
      sv = Webhookdb::Fixtures.saved_view.create(organization: org, name: "hello-there")
      expect { sv.destroy }.to raise_error(Webhookdb::InvariantViolation, /became invalid/)
    end

    it "noops if the org database has not been created" do
      sv = Webhookdb::Fixtures.saved_view.create(organization: org)
      expect { sv.destroy }.to_not raise_error
    end
  end
end
