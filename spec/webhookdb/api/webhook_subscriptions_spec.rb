# frozen_string_literal: true

require "webhookdb/api/webhook_subscriptions"

RSpec.describe Webhookdb::API::WebhookSubscriptions, :db do
  include Rack::Test::Methods

  let(:app) { described_class.build_app }
  let!(:customer) { Webhookdb::Fixtures.customer.create }
  let!(:org) { Webhookdb::Fixtures.organization.create }
  let!(:membership) { Webhookdb::Fixtures.organization_membership(customer:, organization: org).verified.create }
  let!(:sint) { Webhookdb::Fixtures.service_integration.create(organization: org, service_name: "fake_v1") }

  before(:each) do
    login_as(customer)
  end

  after(:each) do
    Webhookdb::Services::Fake.reset
  end

  describe "GET /v1/organizations/:identifier/webhook_subscriptions" do
    it "returns the subscriptions for the org and any service integrations" do
      sint_sub = Webhookdb::Fixtures.webhook_subscription.create(service_integration: sint)
      org_sub = Webhookdb::Fixtures.webhook_subscription.create(organization: org)

      get "/v1/organizations/#{org.key}/webhook_subscriptions"

      expect(last_response).to have_status(200)
      expect(last_response).to have_json_body.that_includes(
        items: have_same_ids_as(sint_sub, org_sub).pk_field(:opaque_id),
      )
    end

    it "returns a message if there are no subscriptions" do
      get "/v1/organizations/#{org.key}/webhook_subscriptions"

      expect(last_response).to have_status(200)
      expect(last_response).to have_json_body.that_includes(
        items: [],
        message: include("has no webhook subscriptions set up"),
      )
    end
  end

  describe "POST /v1/organizations/:identifier/webhook_subscriptions/create" do
    it "403s if service integration with given identifier doesn't exist" do
      post "/v1/organizations/#{org.key}/webhook_subscriptions/create",
           service_integration_identifier: "fakesint", webhook_secret: "wh_secret", url: "https://example.com"

      expect(last_response).to have_status(403)
      expect(last_response).to have_json_body.that_includes(
        error: include(message: "There is no service integration with that identifier."),
      )
    end

    it "creates webhook subscription for service integration" do
      post "/v1/organizations/#{org.key}/webhook_subscriptions/create",
           service_integration_identifier: sint.opaque_id,
           webhook_secret: "wh_secret",
           url: "https://example.com"

      expect(last_response).to have_status(200)
      new_subscription = Webhookdb::WebhookSubscription.where(service_integration: sint).first
      expect(new_subscription).to_not be_nil
      expect(new_subscription.webhook_secret).to eq("wh_secret")
      expect(new_subscription.deliver_to_url).to eq("https://example.com")
      expect(new_subscription.opaque_id).to_not be_nil
    end

    it "returns a webhook subscription entity for service integration" do
      post "/v1/organizations/#{org.key}/webhook_subscriptions/create",
           service_integration_identifier: sint.opaque_id, webhook_secret: "wh_secret", url: "https://example.com"

      expect(last_response).to have_status(200)
      new_subscription = Webhookdb::WebhookSubscription.where(service_integration: sint).first
      expect(last_response).to have_json_body.that_includes(
        deliver_to_url: "https://example.com",
        opaque_id: new_subscription.opaque_id,
        organization: nil,
        service_integration: include(opaque_id: sint.opaque_id),
      )
    end

    it "can use deprecated param `service_integration_opaque_id`" do
      post "/v1/organizations/#{org.key}/webhook_subscriptions/create",
           service_integration_opaque_id: sint.opaque_id,
           webhook_secret: "wh_secret",
           url: "https://example.com"

      expect(last_response).to have_status(200)
    end

    it "prefers 'service_integration_identifier' over 'service_integration_opaque_id' parameter" do
      post "/v1/organizations/#{org.key}/webhook_subscriptions/create",
           service_integration_identifier: sint.opaque_id,
           service_integration_opaque_id: "fakesint",
           webhook_secret: "wh_secret",
           url: "https://example.com"

      # if the deprecated param were used, this would be a 403 integration not found
      expect(last_response).to have_status(200)
    end

    it "403s if user doesn't have permissions for organization assocatied with service integration" do
      membership.destroy

      post "/v1/organizations/#{org.key}/webhook_subscriptions/create",
           service_integration_identifier: sint.opaque_id, webhook_secret: "wh_secret", url: "https://example.com"

      expect(last_response).to have_status(403)
      expect(last_response).to have_json_body.that_includes(
        error: include(message: "You don't have permissions with that organization."),
      )
    end

    it "403s if organization with given identifier doesn't exist" do
      post "/v1/organizations/fakeorg/webhook_subscriptions/create",
           webhook_secret: "wh_secret", url: "https://example.com"

      expect(last_response).to have_status(403)
      expect(last_response).to have_json_body.that_includes(
        error: include(message: "There is no organization with that identifier."),
      )
    end

    it "creates webhook subscription for organization" do
      post "/v1/organizations/#{org.key}/webhook_subscriptions/create",
           webhook_secret: "wh_secret", url: "https://example.com"

      expect(last_response).to have_status(200)
      new_subscription = Webhookdb::WebhookSubscription.where(organization: org).first
      expect(new_subscription).to_not be_nil
      expect(new_subscription.webhook_secret).to eq("wh_secret")
      expect(new_subscription.deliver_to_url).to eq("https://example.com")
      expect(new_subscription.opaque_id).to_not be_nil
    end

    it "returns a webhook subscription entity for organization" do
      post "/v1/organizations/#{org.key}/webhook_subscriptions/create",
           service_integration_identifier: "", webhook_secret: "wh_secret", url: "https://example.com"

      expect(last_response).to have_status(200)
      new_subscription = Webhookdb::WebhookSubscription.where(organization: org).first
      expect(last_response).to have_json_body.that_includes(
        deliver_to_url: "https://example.com",
        opaque_id: new_subscription.opaque_id,
        organization: include(id: org.id),
        service_integration: nil,
      )
    end

    it "403s if user doesn't have permissions for organization" do
      membership.destroy

      post "/v1/organizations/#{org.key}/webhook_subscriptions/create",
           webhook_secret: "wh_secret", url: "https://example.com"

      expect(last_response).to have_status(403)
      expect(last_response).to have_json_body.that_includes(
        error: include(message: "You don't have permissions with that organization."),
      )
    end
  end

  describe "POST /v1/organizations/:identifier/webhook_subscriptions/:opaque_id/test" do
    it "emits test webhook event", :async do
      webhook_sub = Webhookdb::Fixtures.webhook_subscription.create(service_integration: sint)
      expect do
        post "/v1/organizations/#{org.key}/webhook_subscriptions/#{webhook_sub.opaque_id}/test"
        expect(last_response).to have_status(200)
      end.to publish("webhookdb.webhooksubscription.test")
    end

    it "403s if the subscription does not belong to an org the user has access to" do
      webhook_sub = Webhookdb::Fixtures.webhook_subscription.create

      post "/v1/organizations/#{org.key}/webhook_subscriptions/#{webhook_sub.opaque_id}/test"

      expect(last_response).to have_status(403)
      expect(last_response).to have_json_body.that_includes(
        error: include(message: "No webhook subscription with that ID exists in that organization."),
      )
    end

    it "403s if user doesn't have permissions for organization" do
      membership.destroy

      webhook_sub = Webhookdb::Fixtures.webhook_subscription.create(service_integration: sint)
      post "/v1/organizations/#{org.key}/webhook_subscriptions/#{webhook_sub.opaque_id}/test"

      expect(last_response).to have_status(403)
      expect(last_response).to have_json_body.that_includes(
        error: include(message: "You don't have permissions with that organization."),
      )
    end
  end

  describe "POST /v1/organizations/:identifier/webhook_subscriptions/:opaque_id/delete" do
    it "deletes webhook subscription" do
      webhook_sub = Webhookdb::Fixtures.webhook_subscription.create(service_integration: sint)

      post "/v1/organizations/#{org.key}/webhook_subscriptions/#{webhook_sub.opaque_id}/delete"

      expect(last_response).to have_status(200)
      expect(Webhookdb::WebhookSubscription[id: webhook_sub.id]).to be_nil
    end

    it "403s if user doesn't have permissions for organization" do
      membership.destroy
      webhook_sub = Webhookdb::Fixtures.webhook_subscription.create(service_integration: sint)

      post "/v1/organizations/#{org.key}/webhook_subscriptions/#{webhook_sub.opaque_id}/delete"

      expect(last_response).to have_status(403)
      expect(last_response).to have_json_body.that_includes(
        error: include(message: "You don't have permissions with that organization."),
      )
    end
  end

  describe "obsolete endpoints" do
    it "403s for POST /v1/webhook_subscriptions/create" do
      post "/v1/webhook_subscriptions/create"
      expect(last_response).to have_status(403)
      expect(last_response).to have_json_body.that_includes(error: include(code: "endpoint_removed"))
    end

    it "403s for POST /v1/webhook_subscriptions/:opaque_id/test" do
      post "/v1/webhook_subscriptions/1/test"
      expect(last_response).to have_status(403)
      expect(last_response).to have_json_body.that_includes(error: include(code: "endpoint_removed"))
    end

    it "403s for POST /v1/webhook_subscriptions/:opaque_id/delete" do
      post "/v1/webhook_subscriptions/1/delete"
      expect(last_response).to have_status(403)
      expect(last_response).to have_json_body.that_includes(error: include(code: "endpoint_removed"))
    end
  end
end
