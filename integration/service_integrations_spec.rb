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
    end.to eventually(have_attributes(length: 1)).pause_for(1).within(30)
  end

  it "can upsert data synchrononously through endpoint" do
    c = auth_customer
    expect { c.refresh.all_memberships }.to eventually(have_attributes(length: 1))
    org = c.verified_memberships.last.organization
    expect { org.refresh }.to eventually(have_attributes(readonly_connection_url: be_present))
    org.add_feature_role(Webhookdb::Role.find_or_create(name: "internal"))
    sint = Webhookdb::Fixtures.service_integration(organization: org).create
    sint.service_instance.create_table

    resp = post(
      "/v1/organizations/#{org.id}/service_integrations/#{sint.opaque_id}/upsert",
      body: {my_id: "id", at: Time.now},
      json: true,
    )
    expect(resp).to party_status(200)
    expect(resp).to party_response(match(hash_including(message: /You have upserted/)))

    expect(sint.service_instance.readonly_dataset(&:all)).to contain_exactly(include(my_id: "id"))
  end
end
