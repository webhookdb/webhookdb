# frozen_string_literal: true

require "webhookdb/postgres/model"
require "sequel/plugins/soft_deletes"

class Webhookdb::ServiceIntegration < Webhookdb::Postgres::Model(:service_integrations)
  plugin :timestamps
  plugin :soft_deletes

  many_to_one :organization, class: "Webhookdb::Organization"

  def process_state_change(field, value)
    return Webhookdb::Services.service_instance(self).process_state_change(field, value)
  end

  def calculate_create_state_machine
    return Webhookdb::Services.service_instance(self).calculate_create_state_machine(self.organization)
  end

  def calculate_backfill_state_machine
    return Webhookdb::Services.service_instance(self).calculate_backfill_state_machine(self.organization)
  end

  def can_be_modified_by?(customer)
    return customer.verified_member_of?(self.organization)
  end

  # @!attribute table_name
  #   @return [String] Name of the table

  # @!attribute service_name
  #   @return [String] Lookup name of the service

  # @!attribute api_url
  #   @return [String] Root Url of the api to backfill from

  # @!attribute backfill_key
  #   @return [String] Key for backfilling.

  # @!attribute backfill_secret
  #   @return [String] Password/secret for backfilling.
end
