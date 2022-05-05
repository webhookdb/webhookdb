# frozen_string_literal: true

RSpec.describe "Webhookdb::LoggedWebhook", :db, :async do
  let(:described_class) { Webhookdb::LoggedWebhook }

  describe "associations" do
    it "can look up the service integration" do
      sint = Webhookdb::Fixtures.service_integration.create
      lw = Webhookdb::Fixtures.logged_webhook.create(service_integration_opaque_id: "abc")
      expect(lw).to have_attributes(service_integration: nil)
      lw.refresh.service_integration_opaque_id = sint.opaque_id
      expect(lw).to have_attributes(service_integration: be === sint)
    end
  end

  describe "truncate_logs" do
    it "truncates instances" do
      lw = Webhookdb::Fixtures.logged_webhook.create
      described_class.truncate_logs(lw)
      expect(lw).to_not be_truncated
      lw.refresh
      expect(lw).to be_truncated
    end
  end

  describe "truncate_dataset" do
    it "truncates what is in the dataset" do
      lw1 = Webhookdb::Fixtures.logged_webhook.create
      lw2 = Webhookdb::Fixtures.logged_webhook.create
      described_class.truncate_dataset(described_class.where(id: lw2.id))
      expect(lw1.refresh).to_not be_truncated
      expect(lw2.refresh).to be_truncated
    end
  end

  describe "retry_logs" do
    it "retries and returns results" do
      stub_request(:post, "http://localhost:18001/v1/service_integrations/a").
        with(body: "{\"a\":1}").
        to_return(status: 202)
      stub_request(:post, "http://localhost:18001/v1/service_integrations/b").
        with(body: "{}").
        to_return(status: 400)
      lw1 = Webhookdb::Fixtures.logged_webhook(service_integration_opaque_id: "a").body(a: 1).create
      lw2 = Webhookdb::Fixtures.logged_webhook(service_integration_opaque_id: "b").create
      good, bad = described_class.retry_logs([lw1, lw2])
      expect(good).to contain_exactly(lw1)
      expect(bad).to contain_exactly(lw2)
    end

    it "can truncate successes" do
      lw1 = Webhookdb::Fixtures.logged_webhook(service_integration_opaque_id: "a").create
      lw2 = Webhookdb::Fixtures.logged_webhook(service_integration_opaque_id: "b").create
      stub_request(:post, "http://localhost:18001/v1/service_integrations/a").to_return(status: 202)
      stub_request(:post, "http://localhost:18001/v1/service_integrations/b").to_return(status: 400)
      described_class.retry_logs([lw1, lw2], truncate_successful: true)
      expect(lw1.refresh).to be_truncated
      expect(lw2.refresh).to_not be_truncated
    end

    it "does not add non-overridable or webserver headers" do
      lw = Webhookdb::Fixtures.logged_webhook(service_integration_opaque_id: "a").
        body('{"a": 1}').
        headers(
          "Connection" => "explode",
          "Foo" => "bar",
          "Host" => "webhookdb.com",
          "Accept" => "custom stuff",
          "Version" => "HTTP/99",
          "User-Agent" => "curl/7.64.1",
        ).create
      req = stub_request(:post, "http://localhost:18001/v1/service_integrations/a").
        with(
          body: "{\"a\": 1}",
          headers: {
            "Accept" => "*/*",
            "Accept-Encoding" => "gzip;q=1.0,deflate;q=0.6,identity;q=0.3",
            "Content-Type" => "application/json",
            "Foo" => "bar",
            "User-Agent" => "curl/7.64.1",
          },
        ).
        to_return(status: 200, body: "", headers: {})
      described_class.retry_logs([lw], truncate_successful: true)
      expect(req).to have_been_made
    end
  end

  describe "retry_one" do
    it "returns true on success" do
      lw = Webhookdb::Fixtures.logged_webhook(service_integration_opaque_id: "a").create
      stub_request(:post, "http://localhost:18001/v1/service_integrations/a").to_return(status: 202)
      expect(lw.retry_one).to be_truthy
    end

    it "returns false on failure" do
      lw = Webhookdb::Fixtures.logged_webhook(service_integration_opaque_id: "a").create
      stub_request(:post, "http://localhost:18001/v1/service_integrations/a").to_return(status: 500)
      expect(lw.retry_one).to be_falsey
    end
  end

  describe "trim" do
    it "deletes old, and truncates error/successes, as per method docs" do
      fac = Webhookdb::Fixtures.logged_webhook
      orphan_ancient = fac.ancient.create
      orphan_newer = fac.failure.create

      ofac = fac.with_organization
      success_newer = ofac.success.create
      success_older = ofac.success.create(inserted_at: 20.days.ago)
      success_ancient = ofac.success.ancient.create
      failure_newer = ofac.failure.create
      failure_mid = ofac.failure.create(inserted_at: 20.days.ago)
      failure_older = ofac.failure.create(inserted_at: 40.days.ago)
      failure_ancient = ofac.failure.ancient.create

      described_class.trim

      expect(described_class.naked.select(:id, :request_body).all).to have_same_ids_as(
        orphan_newer,
        success_newer,
        success_older,
        failure_newer,
        failure_mid,
        failure_older,
      )

      expect(orphan_newer.refresh).to_not be_truncated
      expect(success_newer.refresh).to_not be_truncated
      expect(success_older.refresh).to be_truncated
      expect(failure_newer.refresh).to_not be_truncated
      expect(failure_mid.refresh).to_not be_truncated
      expect(failure_older.refresh).to be_truncated
    end
  end
end
