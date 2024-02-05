# frozen_string_literal: true

require "webhookdb/saved_query"

RSpec.describe "Webhookdb::SavedQuery", :db do
  let(:described_class) { Webhookdb::SavedQuery }
  let(:org) { Webhookdb::Fixtures.organization.create }

  it "has appropriate associations" do
    cq = Webhookdb::Fixtures.saved_query(organization: org).created_by.create
    expect(cq).to have_attributes(
      created_by: be_a(Webhookdb::Customer),
    )
  end

  it "generates an opaque id on save" do
    cq = Webhookdb::Fixtures.saved_query.create
    expect(cq).to have_attributes(opaque_id: match(/svq_\w+/))
  end
end
