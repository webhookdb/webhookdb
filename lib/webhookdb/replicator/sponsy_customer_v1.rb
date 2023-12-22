# frozen_string_literal: true

require "webhookdb/replicator/sponsy_v1_mixin"

class Webhookdb::Replicator::SponsyCustomerV1 < Webhookdb::Replicator::Base
  include Appydays::Loggable
  include Webhookdb::Replicator::SponsyV1Mixin

  def self.descriptor
    return Webhookdb::Replicator::Descriptor.new(
      name: "sponsy_customer_v1",
      ctor: self,
      feature_roles: [],
      resource_name_singular: "Sponsy Customer",
      dependency_descriptor: Webhookdb::Replicator::SponsySlotV1.descriptor,
      supports_backfill: true,
      api_docs_url: "https://api.getsponsy.com/docs",
    )
  end

  def _denormalized_columns
    return [
      Webhookdb::Replicator::Column.new(:name, TEXT),
      Webhookdb::Replicator::Column.new(:logo, TEXT, optional: true),
      Webhookdb::Replicator::Column.new(:notes, TEXT, optional: true),
      Webhookdb::Replicator::Column.new(:portal_text, TEXT, data_key: "portalText", optional: true),
      Webhookdb::Replicator::Column.new(:portal_id, TEXT, data_key: "portalId", index: true, optional: true),
    ].concat(self._ts_columns)
  end

  def _backfillers
    return [Backfiller.new(service: self)]
  end

  class Backfiller < Webhookdb::Backfiller
    def initialize(service:)
      @service = service
      @slot_service = service.service_integration.depends_on.replicator
      super()
    end

    def handle_item(body)
      @service.upsert_webhook_body(body)
    end

    def fetch_backfill_page(_pagination_token, last_backfilled:)
      customers = @slot_service.admin_dataset do |ds|
        (ds = ds.where { updated_at > last_backfilled }) if last_backfilled
        ds.select_map(Sequel.pg_json(:data)["customer"].as(:customer))
      end
      return customers, nil
    end
  end
end
