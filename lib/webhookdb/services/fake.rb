# frozen_string_literal: true

class Webhookdb::Services::Fake < Webhookdb::Services::Base
  extend Webhookdb::MethodUtilities

  singleton_attr_accessor :webhook_response
  singleton_attr_accessor :webhook_verified
  singleton_attr_accessor :prepare_for_insert_hook

  def self.descriptor
    return {
      name: "fake_v1",
      ctor: ->(sint) { Webhookdb::Services::Fake.new(sint) },
      feature_roles: ["internal"],
    }
  end

  def self.reset
    self.webhook_response = nil
    self.webhook_verified = true
    self.prepare_for_insert_hook = nil
  end

  def self.stub_backfill_request(items, status: 200)
    return WebMock::API.stub_request(:get, "https://fake-integration/?token=").
        to_return(status:, body: [items, nil].to_json, headers: {"Content-Type" => "application/json"})
  end

  def webhook_response(request)
    return self.class.webhook_response || super
  end

  def calculate_create_state_machine
    step = Webhookdb::Services::StateMachineStep.new
    # if the service integration doesn't exist, create it with some standard values
    unless self.service_integration.webhook_secret.present?
      step.output = "You're creating a fake_v1 service integration."
      return step.prompting("fake API secret").webhook_secret(self.service_integration)
    end

    step.output = "The integration creation flow is working correctly. Here is " \
                  "the integration's opaque id, which you'll need to enter in a second: " \
                  "#{self.service_integration.opaque_id}"
    return step.completed
  end

  def calculate_backfill_state_machine
    step = Webhookdb::Services::StateMachineStep.new
    # if the service integration doesn't exist, create it with some standard values
    unless self.service_integration.backfill_secret.present?
      step.needs_input = true
      step.output = "Now let's test the backfill flow."
      step.prompt = "Paste or type a string here:"
      step.prompt_is_secret = false
      step.post_to_url = self.service_integration.unauthed_webhook_path + "/transition/backfill_secret"
      step.complete = false
      return step
    end

    step.needs_input = false
    step.output = "The backfill flow is working correctly."
    step.complete = true
    return step
  end

  def _webhook_verified?(_request)
    v = self.class.webhook_verified
    raise v if v.is_a?(Exception)
    return v
  end

  def _remote_key_column
    return Webhookdb::Services::Column.new(:my_id, "text")
  end

  def _denormalized_columns
    return [
      Webhookdb::Services::Column.new(:at, "timestamptz", index: true),
    ]
  end

  def _update_where_expr
    return Sequel[self.table_sym][:at] < Sequel[:excluded][:at]
  end

  def _prepare_for_insert(body, *)
    h = {
      my_id: body["my_id"],
      at: Time.parse(body["at"]),
    }
    (h = self.class.prepare_for_insert_hook.call(h)) if self.class.prepare_for_insert_hook
    return h
  end

  def _fetch_backfill_page(pagination_token, **_kwargs)
    r = Webhookdb::Http.get("https://fake-integration?token=#{pagination_token}", logger: nil)
    raise "Expected 2-item array" unless r.parsed_response.is_a?(Array) && r.parsed_response.length == 2
    return r.parsed_response
  end
end

class Webhookdb::Services::FakeWithEnrichments < Webhookdb::Services::Fake
  def self.descriptor
    return {
      name: "fake_with_enrichments_v1",
      ctor: ->(sint) { Webhookdb::Services::FakeWithEnrichments.new(sint) },
      feature_roles: ["internal"],
    }
  end

  def self.enrichment_tables
    return ["fake_v1_enrichments"]
  end

  def _create_enrichment_tables_sql
    return "CREATE TABLE fake_v1_enrichments(id TEXT);"
  end

  def _prepare_for_insert(body, enrichment: nil)
    body["enrichment"] = enrichment
    return super
  end

  def _fetch_enrichment(body)
    r = Webhookdb::Http.get("https://fake-integration/enrichment/" + body["my_id"], logger: nil)
    return r.parsed_response
  end

  def _after_insert(inserting, *)
    self.admin_dataset(&:db) << "INSERT INTO fake_V1_enrichments(id) VALUES ('#{inserting['my_id']}')"
  end
end
