# frozen_string_literal: true

require "webhookdb/webhook_subscription"

RSpec.describe "Webhookdb::WebhookSubscription" do
  let(:described_class) { Webhookdb::WebhookSubscription }
  let!(:sint) { Webhookdb::Fixtures.service_integration.create(service_name: "fake_v1") }

  describe "deliver" do
    it "delivers request to correct url with expected body & headers" do
      webhook_sub = Webhookdb::Fixtures.webhook_subscription.create(service_integration: sint, deliver_to_url: "https://example.com/")
      req = stub_request(:post, "https://example.com/").
        with(
          body: "service_name=test_service&table_name=test_service_table&row%5B%5D=echo&row%5B%5D=foxtrot&row%5B%5D=" \
                "golf&external_id=asdfgk&external_id_column=external%20id%20column",
          headers: {
            "Accept" => "*/*",
            "Accept-Encoding" => "gzip;q=1.0,deflate;q=0.6,identity;q=0.3",
            "Content-Type" => "application/json",
            "User-Agent" => "WebhookDB/unknown-release https://webhookdb.com 1970-01-01T00:00:00Z",
            "Webhookdb-Webhook-Secret" => webhook_sub.webhook_secret,
          },
        ).
        to_return(status: 200, body: "", headers: {})

      webhook_sub.deliver(service_name: "test_service", table_name: "test_service_table",
                          row: ["echo", "foxtrot", "golf"], external_id: "asdfgk",
                          external_id_column: "external id column",)
      expect(req).to have_been_made
    end
  end
end
