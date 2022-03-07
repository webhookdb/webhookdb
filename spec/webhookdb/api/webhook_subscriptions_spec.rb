# frozen_string_literal: true

require "webhookdb/api/webhook_subscriptions"

RSpec.describe Webhookdb::API::WebhookSubscriptions, :db do
  include Rack::Test::Methods

  let(:app) { described_class.build_app }
  let!(:customer) { Webhookdb::Fixtures.customer.create }
  let!(:org) { Webhookdb::Fixtures.organization.create }
  let!(:membership) { org.add_membership(customer:, verified: true) }
  let!(:sint) { Webhookdb::Fixtures.service_integration.create(organization: org, service_name: "fake_v1") }

  before(:each) do
    login_as(customer)
  end

  after(:each) do
    Webhookdb::Services::Fake.reset
  end

  describe "POST /v1/webhook_subscriptions/create" do
    it "400s if service integration with given identifier doesn't exist" do
      post "/v1/webhook_subscriptions/create",
           service_integration_opaque_id: "fakesint", webhook_secret: "wh_secret", url: "https://example.com"

      expect(last_response).to have_status(400)
      expect(last_response).to have_json_body.that_includes(
        error: include(message: "There is no integration with that id."),
      )
    end

    it "creates webhook subscription for service integration" do
      post "/v1/webhook_subscriptions/create",
           service_integration_opaque_id: sint.opaque_id,
           org_identifier: "",
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
      post "/v1/webhook_subscriptions/create",
           service_integration_opaque_id: sint.opaque_id, webhook_secret: "wh_secret", url: "https://example.com"

      expect(last_response).to have_status(200)
      new_subscription = Webhookdb::WebhookSubscription.where(service_integration: sint).first
      expect(last_response).to have_json_body.that_includes(
        deliver_to_url: "https://example.com",
        opaque_id: new_subscription.opaque_id,
        organization: nil,
        service_integration: include(opaque_id: sint.opaque_id),
      )
    end

    it "403s if user doesn't have permissions for organization assocatied with service integration" do
      membership.destroy

      post "/v1/webhook_subscriptions/create",
           service_integration_opaque_id: sint.opaque_id, webhook_secret: "wh_secret", url: "https://example.com"

      expect(last_response).to have_status(403)
      expect(last_response).to have_json_body.that_includes(
        error: include(message: "You don't have permissions with that organization."),
      )
    end

    it "400s if organization with given identifier doesn't exist" do
      post "/v1/webhook_subscriptions/create",
           org_identifier: "fakeorg", webhook_secret: "wh_secret", url: "https://example.com"

      expect(last_response).to have_status(403)
      expect(last_response).to have_json_body.that_includes(
        error: include(message: "There is no organization with that identifier."),
      )
    end

    it "creates webhook subscription for organization" do
      post "/v1/webhook_subscriptions/create",
           org_identifier: org.key, webhook_secret: "wh_secret", url: "https://example.com"

      expect(last_response).to have_status(200)
      new_subscription = Webhookdb::WebhookSubscription.where(organization: org).first
      expect(new_subscription).to_not be_nil
      expect(new_subscription.webhook_secret).to eq("wh_secret")
      expect(new_subscription.deliver_to_url).to eq("https://example.com")
      expect(new_subscription.opaque_id).to_not be_nil
    end

    it "returns a webhook subscription entity for organization" do
      post "/v1/webhook_subscriptions/create",
           org_identifier: org.key, service_integration_opaque_id: "", webhook_secret: "wh_secret", url: "https://example.com"

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

      post "/v1/webhook_subscriptions/create",
           org_identifier: org.key, webhook_secret: "wh_secret", url: "https://example.com"

      expect(last_response).to have_status(403)
      expect(last_response).to have_json_body.that_includes(
        error: include(message: "You don't have permissions with that organization."),
      )
    end
  end

  describe "POST /v1/webhook_subscriptions/:opaque_id/test" do
    it "emits test webhook event", :async do
      webhook_sub = Webhookdb::Fixtures.webhook_subscription.create(service_integration: sint)
      expect do
        post "/v1/webhook_subscriptions/#{webhook_sub.opaque_id}/test"
        expect(last_response).to have_status(200)
      end.to publish("webhookdb.webhooksubscription.test")
    end
  end

  describe "POST /v1/webhook_subscriptions/:opaque_id/delete" do
    it "deletes webhook subscription" do
      webhook_sub = Webhookdb::Fixtures.webhook_subscription.create(service_integration: sint)

      post "/v1/webhook_subscriptions/#{webhook_sub.opaque_id}/delete"

      expect(last_response).to have_status(200)
      expect(Webhookdb::WebhookSubscription[id: webhook_sub.id]).to be_nil
    end
  end
end
