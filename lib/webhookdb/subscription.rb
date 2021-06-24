# frozen_string_literal: true

class Webhookdb::Subscription < Webhookdb::Postgres::Model(:subscriptions)
  extend Webhookdb::MethodUtilities
  include Appydays::Configurable
  include Appydays::Loggable

  plugin :timestamps
  plugin :soft_deletes

  configurable(:subscriptions) do
    setting :max_free_integrations, 2
  end

  def initialize(*)
    super
    self[:stripe_json] ||= Sequel.pg_json({})
  end

  def status
    return self.stripe_json["status"]
  end

  def self.lookup_org
    # TODO: test this
    return Webhookdb::Organization.first(stripe_customer_id: self.stripe_customer_id)
  end

  def self.create_or_update_from_webhook(request_params)
    data = request_params["data"]["object"]
    self.db.transaction do
      sub = self.find_or_create_or_find(stripe_id: data["id"])
      sub.update(stripe_json: data.to_json, stripe_customer_id: data["customer"])
      sub.save_changes
    end
  end
end
