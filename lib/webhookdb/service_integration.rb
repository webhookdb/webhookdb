# frozen_string_literal: true

require "webhookdb/postgres/model"

class Webhookdb::ServiceIntegration < Webhookdb::Postgres::Model(:service_integrations)
  plugin :timestamps
  plugin :soft_deletes

  many_to_one :organization, class: "Webhookdb::Organization"

  def initialize(*)
    super
    self.backfill_secret ||= SecureRandom.hex(8)
  end
end
