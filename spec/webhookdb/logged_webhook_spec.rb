# frozen_string_literal: true

RSpec.describe "Webhookdb::LoggedWebhook", :async, :db do
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
    it "truncates what is in the dataset, and not already truncated" do
      lw1 = Webhookdb::Fixtures.logged_webhook.create
      lw2 = Webhookdb::Fixtures.logged_webhook.create
      t = trunc_time(5.days.ago)
      trunc = Webhookdb::Fixtures.logged_webhook.create(truncated_at: t)
      described_class.truncate_dataset(described_class.where(id: [lw2.id, trunc.id]))
      expect(lw1.refresh).to_not be_truncated
      expect(lw2.refresh).to have_attributes(
        request_body: "", request_headers: {}, truncated_at: match_time(:now).within(1),
      )
      expect(trunc.refresh).to have_attributes(truncated_at: t)
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

    it "includes the retry header" do
      lw = Webhookdb::Fixtures.logged_webhook(service_integration_opaque_id: "a").create
      req = stub_request(:post, "http://localhost:18001/v1/service_integrations/a").
        with(headers: {"Whdb-Logged-Webhook-Retry" => lw.id.to_s}).
        to_return(status: 200, body: "", headers: {})
      described_class.retry_logs([lw])
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
      t = trunc_time(5.days.ago)
      success_truncated = ofac.success.truncated(t).create(inserted_at: 20.days.ago)
      success_ancient = ofac.success.truncated.ancient.create
      failure_newer = ofac.failure.create
      failure_mid = ofac.failure.create(inserted_at: 20.days.ago)
      failure_older = ofac.failure.create(inserted_at: 40.days.ago)
      failure_ancient = ofac.failure.ancient.truncated.create

      described_class.trim

      expect(described_class.naked.select(:id, :request_body).all).to have_same_ids_as(
        orphan_newer,
        success_newer,
        success_older,
        success_truncated,
        failure_newer,
        failure_mid,
        failure_older,
      )

      expect(orphan_newer.refresh).to_not be_truncated
      expect(success_newer.refresh).to_not be_truncated
      expect(success_older.refresh).to be_truncated
      expect(success_truncated.refresh).to have_attributes(truncated_at: t)
      expect(failure_newer.refresh).to_not be_truncated
      expect(failure_mid.refresh).to_not be_truncated
      expect(failure_older.refresh).to be_truncated
    end
  end

  describe "Resilient" do
    include Webhookdb::SpecHelpers::Async::ResilientAction

    resil = Webhookdb::LoggedWebhook::Resilient.new

    def values(opaqueid)
      return {
        request_path: "/service_integrations/#{opaqueid}",
        request_body: "{}",
        request_headers: "{}",
        request_method: "POST",
        response_status: 0,
        service_integration_opaque_id: opaqueid,
      }
    end

    describe "resilient_insert" do
      def cause_insert_error
        # This is the easiest way.
        described_class.db << "DROP TABLE logged_webhooks"
      end

      it "does nothing if the insert succeeds" do
        logs = capture_logs_from(described_class.logger, level: :debug, formatter: :json) do
          expect(described_class.resilient_insert(**values("x"))).to be_a(Integer)
        end
        expect(logs).to be_empty
        expect(described_class.all).to contain_exactly(include(service_integration_opaque_id: "x"))
      end

      it "logs an error and raises if no resilient insert succeeds" do
        cause_insert_error
        described_class.available_resilient_database_urls = []
        logs = capture_logs_from(described_class.logger, level: :info, formatter: :json) do
          expect do
            described_class.resilient_insert(**values("x"))
          end.to raise_error(Sequel::DatabaseError, /relation "logged_webhooks" does not exist/)
        end
        expect(logs).to contain_exactly(include_json(level: "error", message: "resilient_insert_unhandled"))
      end

      it "inserts into the first available database and logs a warning" do
        described_class.available_resilient_database_urls = [
          "#{resilient_url}_INVALID1",
          resilient_url,
          "#{resilient_url}_INVALID2",
        ]
        cause_insert_error
        logs = capture_logs_from(described_class.logger, level: :info, formatter: :json) do
          expect(described_class.resilient_insert(**values("x"))).to be(true)
        end
        expect(logs).to contain_exactly(include_json(level: "warn", message: "resilient_insert_handled"))
        expect(resilient_webhooks_dataset(&:all)).to contain_exactly(
          include(
            json_payload: '{"request_path":"/service_integrations/x","request_body":"{}","request_headers":"{}",' \
                          '"request_method":"POST","response_status":0}',
            json_meta: '{"service_integration_opaque_id":"x"}',
          ),
        )
      end

      it "handles multiple and concurrent inserts", db: :no_transaction do
        described_class.available_resilient_database_urls = [
          "#{resilient_url}_INVALID1",
          resilient_url,
        ]
        # Using threads causes issues with connection pools, so fake it out.
        # The 201st time is due to unit tests, we only get 200 calls from resilient_insert
        # We cannot mock dataset.insert unfortunately.
        expect(described_class).to receive(:dataset).and_raise(Sequel::DatabaseError).exactly(51).times
        errors = []
        threads = Array.new(5) do |i|
          logging_thread(errors, name: "resilwh-#{i}") do
            Array.new(10) do |j|
              described_class.resilient_insert(**values("id-#{i}-#{j}"))
            end
          end
        end
        threads.each(&:join)
        expect(errors).to be_empty
        expect(resilient_webhooks_dataset(&:all)).to have_length(50)
      end
    end

    describe "resilient_replay" do
      before(:each) do
        described_class.available_resilient_database_urls = [resilient_url]
      end

      it "creates logged webhooks and deletes in all reachable resilient dbs" do
        resil.write_to(resilient_url, values("x").to_json, {service_integration_opaque_id: "x"}.to_json)
        resil.write_to(resilient_url, values("z").to_json, {service_integration_opaque_id: "z"}.to_json)
        expect do
          expect(resil.replay).to eq(2)
        end.to publish("webhookdb.loggedwebhook.replay").with_payload(contain_exactly(be_an(Integer)))
        expect(described_class.dataset.select_map(&:service_integration_opaque_id)).to contain_exactly("x", "z")
        expect(resilient_webhooks_dataset(&:all)).to be_empty
      end

      it "ignores unreachable resilient databases" do
        described_class.available_resilient_database_urls = ["#{resilient_url}_INVALID"]
        expect(resil.replay).to be_nil
      end

      it "noops if the primary db is unavailable" do
        expect(described_class.db).to receive(:execute).and_raise(Sequel::DatabaseError)
        expect(resil.replay).to be_nil
      end
    end
  end
end
