# frozen_string_literal: true

require "rspec/eventually"

RSpec.describe "service integrations", :integration do
  def catch_missing_db(default)
    yield
  rescue Sequel::DatabaseError
    return default
  end

  it "can create a full webhookdb customer integration and POST webhooks" do
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
      catch_missing_db(["default"]) { sint.replicator.readonly_dataset(&:all) }
    end.to eventually(be_empty)

    with_async_publisher do
      Webhookdb::Fixtures.customer.create
    end

    expect do
      catch_missing_db(["default"]) { sint.replicator.readonly_dataset(&:all) }
    end.to eventually(have_attributes(length: 1))

    # puts sint.opaque_id, "/v1/service_integrations/#{sint.opaque_id}"
    resp = post(
      "/v1/service_integrations/#{sint.opaque_id}",
      body: c.values.as_json,
      headers: {"Whdb-Secret" => sint.webhook_secret},
      json: true,
    )
    expect(resp).to party_status(202)
    expect(resp).to party_response(match(o: "k"))
    logged_whs = Webhookdb::LoggedWebhook.where(service_integration_opaque_id: sint.opaque_id).all
    expect(logged_whs).to_not be_empty
  end

  it "can upsert data synchrononously through endpoint" do
    c = auth_customer
    expect { c.refresh.all_memberships }.to eventually(have_attributes(length: 1))
    org = c.verified_memberships.last.organization
    expect { org.refresh }.to eventually(have_attributes(readonly_connection_url: be_present))
    org.add_feature_role(Webhookdb::Role.find_or_create(name: "internal"))
    sint = Webhookdb::Fixtures.service_integration(organization: org).create
    sint.replicator.create_table

    resp = post(
      "/v1/organizations/#{org.id}/service_integrations/#{sint.opaque_id}/upsert",
      body: {my_id: "id", at: Time.now},
      json: true,
    )
    expect(resp).to party_status(200)
    expect(resp).to party_response(match(hash_including(message: /You have upserted/)))

    expect(sint.replicator.readonly_dataset(&:all)).to contain_exactly(include(my_id: "id"))
  end
end
