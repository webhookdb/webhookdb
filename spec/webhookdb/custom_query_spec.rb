# frozen_string_literal: true

require "webhookdb/custom_query"

RSpec.describe "Webhookdb::CustomQuery" do
  let(:described_class) { Webhookdb::CustomQuery }
  let(:org) { Webhookdb::Fixtures.organization.create }

  it "has appropriate associations" do
    cq = Webhookdb::Fixtures.custom_query(organization: org).created_by.create
    expect(cq).to have_attributes(
      created_by: be_a(Webhookdb::Customer),
    )
  end

  it "generates an opaque id on save" do
    cq = Webhookdb::Fixtures.custom_query.create
    expect(cq).to have_attributes(opaque_id: match(/cq_\w+/))
  end
end
