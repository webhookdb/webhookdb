# frozen_string_literal: true

class Webhookdb::Services::Fake < Webhookdb::Services::Base
  extend Webhookdb::MethodUtilities

  singleton_attr_accessor :webhook_response
  singleton_attr_accessor :webhook_verified
  singleton_attr_accessor :backfill_responses
  singleton_attr_accessor :prepare_for_insert_hook

  def self.reset
    self.webhook_response = nil
    self.webhook_verified = true
    self.backfill_responses = {}
    self.prepare_for_insert_hook = nil
  end

  def webhook_response(request)
    return self.class.webhook_response || super
  end

  def process_state_change(field, value)
    self.service_integration.db.transaction do
      self.service_integration.send("#{field}=", value)
      self.service_integration.save_changes
      case field
        when "webhook_secret"
          return self.calculate_create_state_machine(self.service_integration.organization)
        when "backfill_secret"
          return self.calculate_backfill_state_machine(self.service_integration.organization)
      else
          return
      end
    end
  end

  def calculate_create_state_machine(_organization)
    step = Webhookdb::Services::StateMachineStep.new
    # if the service integration doesn't exist, create it with some standard values
    unless self.service_integration.webhook_secret.present?
      step.needs_input = true
      step.output = "You're creating a fake_v1 service integration."
      step.prompt = "Paste or type your fake API secret here:"
      step.prompt_is_secret = false
      step.post_to_url = "/v1/service_integrations/#{self.service_integration.opaque_id}/transition/webhook_secret"
      step.complete = false
      return step
    end

    step.needs_input = false
    step.output = "The integration creation flow is working correctly. Here is " \
"the integration's opaque id, which you'll need to enter in a second: #{self.service_integration.opaque_id}"
    step.complete = true
    return step
  end

  def calculate_backfill_state_machine(_organization)
    step = Webhookdb::Services::StateMachineStep.new
    # if the service integration doesn't exist, create it with some standard values
    unless self.service_integration.backfill_secret.present?
      step.needs_input = true
      step.output = "Now let's test the backfill flow."
      step.prompt = "Paste or type a string here:"
      step.prompt_is_secret = false
      step.post_to_url = "/v1/service_integrations/#{self.service_integration.opaque_id}/transition/backfill_secret"
      step.complete = false
      return step
    end

    step.needs_input = false
    step.output = "The backfill flow is working correctly."
    step.complete = true
    return step
  end

  def _webhook_verified?(_request)
    return self.class.webhook_verified
  end

  def _remote_key_column
    return Webhookdb::Services::Column.new(:my_id, "text")
  end

  def _denormalized_columns
    return [
      Webhookdb::Services::Column.new(:at, "timestamptz"),
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

  def _fetch_backfill_page(pagination_token)
    raise "No backfill responses configured" if self.class.backfill_responses.blank?
    return self.class.backfill_responses[pagination_token]
  end
end

class Webhookdb::Services::FakeWithEnrichments < Webhookdb::Services::Fake
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
    return {"extra" => body["my_id"]}
  end

  def _after_insert(inserting, *)
    self.admin_dataset(&:db) << "INSERT INTO fake_V1_enrichments(id) VALUES ('#{inserting['my_id']}')"
  end
end
