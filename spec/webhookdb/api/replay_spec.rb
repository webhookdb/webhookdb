# frozen_string_literal: true

require "webhookdb/api/replay"

RSpec.describe Webhookdb::API::Replay, :async, :db do
  include Rack::Test::Methods

  let(:app) { described_class.build_app }
  let!(:org) { Webhookdb::Fixtures.organization.create }
  let!(:customer) { Webhookdb::Fixtures.customer.create }

  before(:each) do
    Webhookdb::Fixtures.organization_membership(organization: org, customer:).verified.create
    login_as(customer)
  end

  describe "POST /v1/organizations/:org_identifier/replay", :async do
    it "replays webhooks in the given time period" do
      fac = Webhookdb::Fixtures.logged_webhook(organization: org)
      Timecop.freeze("2022-06-15T12:00:00Z") do
        valid = fac.create(inserted_at: 2.hours.ago)
        truncated = fac.create(inserted_at: 2.hours.ago, truncated_at: Time.now)
        too_old = fac.create(inserted_at: 4.hours.ago)

        expect do
          post "/v1/organizations/#{org.key}/replay", after: 3.hours.ago.utc
          expect(last_response).to have_status(200)
        end.to publish("webhookdb.loggedwebhook.replay").with_payload([valid.id])
      end

      expect(last_response).to have_json_body.
        that_includes(message: "Replaying 1 webhook between 2022-06-15T09:00:00Z and 2022-06-15T12:00:00Z.")
    end

    it "uses 'now' as the default 'before' parameter" do
      Timecop.freeze("2022-06-15T12:00:00Z") do
        post "/v1/organizations/#{org.key}/replay", after: "2022-06-15T05:00:00-04:00"
        expect(last_response).to have_status(200)
      end

      expect(last_response).to have_json_body.
        that_includes(message: "Replaying 0 webhooks between 2022-06-15T05:00:00-04:00 and 2022-06-15T08:00:00-04:00.")
    end

    it "uses '1 hour before' as the default 'after' parameter" do
      Timecop.freeze("2022-06-15T12:00:00Z") do
        post "/v1/organizations/#{org.key}/replay", before: "2022-06-15T08:00:00-01:00"
        expect(last_response).to have_status(200)
      end

      expect(last_response).to have_json_body.
        that_includes(message: "Replaying 0 webhooks between 2022-06-15T07:00:00-01:00 and 2022-06-15T08:00:00-01:00.")
    end

    it "can use a precise time period" do
      Timecop.freeze("2022-06-15T12:00:00Z") do
        post "/v1/organizations/#{org.key}/replay",
             after: "2022-06-14T10:00:00-01:00", before: "2022-06-14T12:00:00-01:00"
        expect(last_response).to have_status(200)
      end

      expect(last_response).to have_json_body.
        that_includes(message: "Replaying 0 webhooks between 2022-06-14T10:00:00-01:00 and 2022-06-14T12:00:00-01:00.")
    end

    it "can pass in the number of hours instead of absolute times" do
      Timecop.freeze("2022-06-15T12:00:00Z") do
        post "/v1/organizations/#{org.key}/replay", hours: 3
        expect(last_response).to have_status(200)
      end

      expect(last_response).to have_json_body.
        that_includes(message: "Replaying 0 webhooks between 2022-06-15T09:00:00Z and 2022-06-15T12:00:00Z.")
    end

    it "errors if the given time period is outside the allowed range" do
      Webhookdb::Fixtures.logged_webhook.create(organization: org)

      Timecop.freeze("2022-06-15T12:00:00Z") do
        post "/v1/organizations/#{org.key}/replay", before: "2021-10-01T01:00:00Z"
      end

      expect(last_response).to have_status(400)
      expect(last_response).to have_json_body.
        that_includes(error: include(message: "Webhooks older than 2022-06-08 12:00:00 UTC cannot be replayed."))
    end

    it "errors if the given time period is longer than the maximum range" do
      Webhookdb::Fixtures.logged_webhook.create(organization: org)

      Timecop.freeze("2022-06-15T12:00:00Z") do
        post "/v1/organizations/#{org.key}/replay", after: 63.hours.ago.iso8601
      end

      expect(last_response).to have_status(400)
      expect(last_response).to have_json_body.
        that_includes(error: include(message: "The maximum webhook replay interval is 4 hours."))
    end

    it "uses a default time period of the last hour" do
      Timecop.freeze("2022-06-15T12:00:00Z") do
        post "/v1/organizations/#{org.key}/replay", hours: 0, before: "", after: ""
        expect(last_response).to have_status(200)
      end

      expect(last_response).to have_json_body.
        that_includes(message: "Replaying 0 webhooks between 2022-06-15T11:00:00Z and 2022-06-15T12:00:00Z.")
    end

    describe "with a service integration id" do
      it "replays the webhooks for the integration" do
        Webhookdb::Fixtures.logged_webhook.create(organization: org)
        Webhookdb::Fixtures.logged_webhook.create
        sint = Webhookdb::Fixtures.service_integration.
          create(organization: org, service_name: "fake_with_enrichments_v1")
        lwh = Webhookdb::Fixtures.logged_webhook.for_service_integration(sint).create
        Webhookdb::Fixtures.logged_webhook.for_service_integration(organization: org).create
        Webhookdb::Fixtures.logged_webhook.for_service_integration.create

        expect do
          post "/v1/organizations/#{org.key}/replay", service_integration_identifier: "fake_with_enrichments_v1"

          expect(last_response).to have_status(200)
        end.to publish("webhookdb.loggedwebhook.replay").with_payload([lwh.id])
        expect(last_response).to have_json_body.that_includes(message: match(/Replaying 1 webhook between /))
      end

      it "403s if the integration does not belong to the org" do
        sint = Webhookdb::Fixtures.service_integration.create

        post "/v1/organizations/#{org.key}/replay", service_integration_identifier: sint.opaque_id

        expect(last_response).to have_status(403)
      end

      it "ignores a blank identifier" do
        post "/v1/organizations/#{org.key}/replay", service_integration_identifier: ""

        expect(last_response).to have_status(200)
        expect(last_response).to have_json_body.that_includes(message: match(/Replaying 0 webhooks between /))
      end
    end

    describe "without a service integration id" do
      it "replays the webhooks for the entire org" do
        org_lwh = Webhookdb::Fixtures.logged_webhook.create(organization: org)
        Webhookdb::Fixtures.logged_webhook.create
        sint1_lwh = Webhookdb::Fixtures.logged_webhook.for_service_integration(organization: org).create
        sint2_lwh = Webhookdb::Fixtures.logged_webhook.for_service_integration(organization: org).create
        Webhookdb::Fixtures.logged_webhook.for_service_integration.create

        expect do
          post "/v1/organizations/#{org.key}/replay"
          expect(last_response).to have_status(200)
        end.to publish("webhookdb.loggedwebhook.replay").with_payload([org_lwh.id]).
          and("webhookdb.loggedwebhook.replay").with_payload([sint1_lwh.id]).
          and("webhookdb.loggedwebhook.replay").with_payload([sint2_lwh.id])
        expect(last_response).to have_json_body.that_includes(message: match(/Replaying 3 webhooks between /))
      end
    end
  end
end
