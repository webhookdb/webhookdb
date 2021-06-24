# frozen_string_literal: true

class Webhookdb::Subscription < Webhookdb::Postgres::Model(:subscriptions)
  extend Webhookdb::MethodUtilities
  include Appydays::Configurable
  include Appydays::Loggable
  #  this class contains helpers for dealing with stripe subscription webhooks

  plugin :timestamps
  plugin :soft_deletes

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

  # add helper for taking json and finding the corresponding org
  #
end
