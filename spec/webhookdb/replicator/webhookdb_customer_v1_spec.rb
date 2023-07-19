# frozen_string_literal: true

require "support/shared_examples_for_replicators"

RSpec.describe Webhookdb::Replicator::WebhookdbCustomerV1, :db do
  it_behaves_like "a replicator", "webhookdb_customer_v1" do
    let(:body) do
      JSON.parse(<<~J)
        {
          "id": "cu_abc123",
          "created_at": "2022-06-13T14:21:04.123Z",
          "updated_at": null,
          "email": "test@webhookdb.com"
        }
      J
    end
  end

  it_behaves_like "a replicator that prevents overwriting new data with old", "webhookdb_customer_v1" do
    let(:old_body) do
      JSON.parse(<<~J)
        {
          "id": "cu_abc123",
          "created_at": "2022-06-13T14:21:04.123Z",
          "updated_at": "2022-06-13T14:21:04.123Z",
          "email": "test@webhookdb.com"
        }
      J
    end
    let(:new_body) do
      JSON.parse(<<~J)
        {
          "id": "cu_abc123",
          "created_at": "2022-06-13T14:21:04.123Z",
          "updated_at": "2022-06-14T14:21:04.123Z",
          "email": "test@webhookdb.com"
        }
      J
    end
  end

  describe "webhook validation" do
    let(:sint) { Webhookdb::Fixtures.service_integration.create(service_name: "webhookdb_customer_v1") }
    let(:svc) { Webhookdb::Replicator.create(sint) }

    it "returns a 401 for a missing header" do
      sint.update(webhook_secret: "abc")
      req = fake_request
      status, _headers, body = svc.webhook_response(req).to_rack
      expect(status).to eq(401)
      expect(body).to include("header is missing")
    end

    it "returns a 401 for an invalid header" do
      sint.update(webhook_secret: "abc")
      req = fake_request
      req.add_header("HTTP_WHDB_SECRET", "xyz")
      status, _headers, body = svc.webhook_response(req).to_rack
      expect(status).to eq(401)
      expect(body).to include("not match configured")
    end

    it "returns a 202 with a valid header header" do
      sint.update(webhook_secret: "abc")
      req = fake_request
      req.add_header("HTTP_WHDB_SECRET", "abc")
      status, _headers, body = svc.webhook_response(req).to_rack
      expect(status).to eq(202)
    end
  end

  describe "state machine calculation" do
    let(:sint) { Webhookdb::Fixtures.service_integration.create(service_name: "webhookdb_customer_v1") }
    let(:svc) { Webhookdb::Replicator.create(sint) }

    describe "calculate_webhook_state_machine" do
      it "sets the secret and confirms the result" do
        sm = sint.replicator.calculate_webhook_state_machine
        expect(sm).to have_attributes(
          needs_input: false,
          prompt: "",
          complete: true,
          output: match("WebhookDB is now listening for changes"),
        )
        expect(sint).to have_attributes(webhook_secret: be_present)
        expect(sint.refresh).to have_attributes(webhook_secret: be_present)
      end
    end
  end

  describe "_prepare_for_insert" do
    let(:sint) { Webhookdb::Fixtures.service_integration.create(service_name: "webhookdb_customer_v1") }
    let(:svc) { Webhookdb::Replicator.create(sint) }

    let(:resource) do
      JSON.parse(<<~J)
        {
          "id": "cu_abc123",
          "created_at": "2022-06-13T14:21:04.123Z",
          "updated_at": "2022-06-14T14:21:04.123Z",
          "email": "test@webhookdb.com"
        }
      J
    end

    # we're testing how the defaulter on the :updated_at field handles the resource information
    it "populates `updated_at` value correctly if present in resource" do
      prepared_hash = svc._prepare_for_insert(resource, nil, nil, nil)
      expect(prepared_hash).to include(updated_at: "2022-06-14T14:21:04.123Z")
    end

    it "uses `created_at` value if `updated_at` not present in resource" do
      resource[:updated_at] = nil
      prepared_hash = svc._prepare_for_insert(resource, nil, nil, nil)
      expect(prepared_hash).to include(updated_at: "2022-06-14T14:21:04.123Z")
    end
  end
end
