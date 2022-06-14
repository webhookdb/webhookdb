# frozen_string_literal: true

require "rspec/eventually"

RSpec.describe "service integrations", :integration do
  def catch_missing_db(default)
    yield
  rescue Sequel::DatabaseError
    return default
  end

  it "can create a full webhookdb customer integration" do
    c = auth_customer
    expect { c.refresh.all_memberships }.to eventually(have_attributes(length: 1))
    org = c.verified_memberships.last.organization
    expect { org.refresh }.to eventually(have_attributes(readonly_connection_url: be_present))
    org.add_feature_role(Webhookdb::Role.find_or_create(name: "internal"))

    resp = post(
      "/v1/organizations/#{org.id}/service_integrations/create",
      body: {service_name: "webhookdb_customer_v1"},
    )
    expect(resp).to party_status(200)

    expect(org.refresh.service_integrations).to have_attributes(length: 1)
    sint = org.service_integrations.first

    expect do
      catch_missing_db(["default"]) { sint.service_instance.readonly_dataset(&:all) }
    end.to eventually(be_empty)

    with_async_publisher do
      Webhookdb::Fixtures.customer.create
    end

    expect do
      catch_missing_db(["default"]) { sint.service_instance.readonly_dataset(&:all) }
    end.to eventually(have_attributes(length: 1))
  end
end
