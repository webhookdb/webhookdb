# frozen_string_literal: true

require "webhookdb/webhook_subscription"

RSpec.describe "Webhookdb::WebhookSubscription", :db do
  let(:described_class) { Webhookdb::WebhookSubscription }
  let!(:sint) { Webhookdb::Fixtures.service_integration.create(service_name: "fake_v1") }

  describe "delivery system" do
    let(:webhook_sub) do
      Webhookdb::Fixtures.webhook_subscription.
        create(service_integration: sint, deliver_to_url: "https://example.com/")
    end
    let(:params) do
      {service_name: "test_service", table_name: "test_service_table",
       row: ["echo", "foxtrot", "golf"], external_id: "asdfgk",
       external_id_column: "external id column",}
    end

    describe "#deliver" do
      it "delivers request to correct url with expected body & headers" do
        req = stub_request(:post, "https://example.com/").
          with(
            body: params.to_json,
            headers: {
              "Accept" => "*/*",
              "Accept-Encoding" => "gzip;q=1.0,deflate;q=0.6,identity;q=0.3",
              "Content-Type" => "application/json",
              "User-Agent" => "WebhookDB/unknown-release https://webhookdb.com 1970-01-01T00:00:00Z",
              "Whdb-Webhook-Secret" => webhook_sub.webhook_secret,
            },
          ).to_return(status: 200, body: "", headers: {})

        webhook_sub.deliver(**params, headers: {"X" => "Y"})
        expect(req).to have_been_made
      end

      it "can deliver a test event" do
        req = stub_request(:post, "https://example.com/").
          with(
            body: {service_name: "test service",
                   table_name: "test_table_name",
                   row: {data: ["alpha", "beta", "charlie", "delta"]},
                   external_id: "extid",
                   external_id_column: "external_id",}.to_json,
            headers: {"Whdb-Test-Event" => "1"},
          ).to_return(status: 200, body: "", headers: {})

        webhook_sub.deliver_test_event(external_id: "extid")
        expect(req).to have_been_made
      end
    end

    describe "enqueue_delivery" do
      it "creates a Delivery instance and enqueues the job" do
        expect(Webhookdb::Jobs::WebhookSubscriptionDeliveryEvent).to receive(:perform_async).
          with(have_attributes(positive?: true))  # Work around numeric predicate for 'be > 0'.
        del = webhook_sub.enqueue_delivery(**params)
        expect(del).to be_a(Webhookdb::WebhookSubscription::Delivery)
      end
    end

    describe "attempt_delivery" do
      let(:delivery) { webhook_sub.create_delivery(params) }

      it "delivers the payload" do
        req = stub_request(:post, "https://example.com/").
          with(
            body: params.to_json,
            headers: {
              "Whdb-Webhook-Secret" => webhook_sub.webhook_secret,
              "Whdb-Attempt" => 1,
            },
          ).to_return(status: 200, body: "", headers: {})

        delivery.attempt_delivery
        expect(req).to have_been_made
      end

      it "enqueues a later retries on delivery failure" do
        expect(Webhookdb::Jobs::WebhookSubscriptionDeliveryEvent).to receive(:perform_in).
          with(1, delivery.id)

        req = stub_request(:post, "https://example.com/").to_return(status: 400, body: "", headers: {})

        delivery.attempt_delivery
        expect(req).to have_been_made
        expect(webhook_sub).to be_active
        expect(delivery.attempt_timestamps).to contain_exactly(be_within(5).of(Time.now))
        expect(delivery.attempt_http_response_statuses).to contain_exactly(400)
      end

      it "uses proper backoff" do
        expect(Webhookdb::Jobs::WebhookSubscriptionDeliveryEvent).to receive(:perform_in).
          with(33, delivery.id)

        delivery.update(
          attempt_timestamps: Array.new(10) { Time.now },
          attempt_http_response_statuses: Array.new(10) { 400 },
        )

        req = stub_request(:post, "https://example.com/").to_return(status: 400, body: "", headers: {})

        delivery.attempt_delivery
        expect(req).to have_been_made
      end

      it "emits developer event and does not reenqueue after max attempts have been tried", :async do
        expect(Webhookdb::Jobs::WebhookSubscriptionDeliveryEvent).to_not receive(:perform_in)

        req = stub_request(:post, "https://example.com/").to_return(status: 400, body: "", headers: {})

        Array.new(described_class::MAX_DELIVERY_ATTEMPTS) { delivery.add_attempt(status: 400) }
        delivery.save_changes

        expect do
          delivery.attempt_delivery
        end.to publish("webhookdb.developeralert.emitted").with_payload(
          match_array([include("subsystem" => "Webhook Subscriptions")]),
        )

        expect(req).to have_been_made
      end

      it "noops if the subscription is deactivated" do
        webhook_sub.deactivate.save_changes
        delivery.attempt_delivery
        expect(delivery.attempts).to be_empty
      end

      it "can calculate the right backoff for a given attempt" do
        expect(described_class.backoff_for_attempt(0)).to eq(1)
        expect(described_class.backoff_for_attempt(1)).to eq(1)
        expect(described_class.backoff_for_attempt(2)).to eq(4)
        expect(described_class.backoff_for_attempt(3)).to eq(6)
        expect(described_class.backoff_for_attempt(10)).to eq(20)
        expect(described_class.backoff_for_attempt(11)).to eq(33)
        expect(described_class.backoff_for_attempt(20)).to eq(60)
        expect(described_class.backoff_for_attempt(21)).to eq(84)
        expect(described_class.backoff_for_attempt(described_class::MAX_DELIVERY_ATTEMPTS)).to eq(100)
      end
    end

    describe "Delivery" do
      let(:delivery) { webhook_sub.create_delivery({}) }

      describe "validations" do
        it "requires equal sized attempt arrays" do
          expect do
            delivery.update(attempt_timestamps: [Time.now], attempt_http_response_statuses: [1, 2])
          end.to raise_error(Sequel::ConstraintViolation)
        end
      end

      it "can describe attempts" do
        t1 = 1.hour.ago
        t2 = Time.now
        delivery.add_attempt(at: t1, status: 201)
        delivery.add_attempt(at: t2, status: 401)
        expect(delivery.attempts).to contain_exactly(
          have_attributes(at: t1, status: 201, success: true),
          have_attributes(at: t2, status: 401, success: false),
        )
      end

      it "can describe its last attempt" do
        expect(delivery).to have_attributes(latest_attempt_status: "pending")
        delivery.add_attempt(status: 201)
        expect(delivery).to have_attributes(latest_attempt_status: "success")
        delivery.add_attempt(status: 401)
        expect(delivery).to have_attributes(latest_attempt_status: "error")
      end
    end
  end

  describe "associated_type and id" do
    it "is '' if no association set" do
      sub = Webhookdb::Fixtures.webhook_subscription.instance
      expect(sub).to have_attributes(associated_type: "", associated_id: "")
    end

    it "is organization if org id is set" do
      sub = Webhookdb::Fixtures.webhook_subscription.for_org(key: "myorg").instance
      expect(sub).to have_attributes(associated_type: "organization", associated_id: "myorg")
    end

    it "is 'service_integration' if sint id is set" do
      sub = Webhookdb::Fixtures.webhook_subscription.for_service_integration(opaque_id: "hello").instance
      expect(sub).to have_attributes(associated_type: "service_integration", associated_id: "hello")
    end
  end
end
