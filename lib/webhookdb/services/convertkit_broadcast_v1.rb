# frozen_string_literal: true

require "time"
require "webhookdb/convertkit"
require "webhookdb/services/convertkit_v1_mixin"

class Webhookdb::Services::ConvertkitBroadcastV1 < Webhookdb::Services::Base
  include Appydays::Loggable
  include Webhookdb::Services::ConvertkitV1Mixin

  # @return [Webhookdb::Services::Descriptor]
  def self.descriptor
    return Webhookdb::Services::Descriptor.new(
      name: "convertkit_broadcast_v1",
      ctor: ->(sint) { Webhookdb::Services::ConvertkitBroadcastV1.new(sint) },
      feature_roles: [],
      resource_name_singular: "ConvertKit Broadcast",
    )
  end

  def calculate_create_state_machine
    return self.calculate_backfill_state_machine
  end

  def _denormalized_columns
    return [
      Webhookdb::Services::Column.new(:click_rate, DECIMAL, from_enrichment: true, optional: true),
      Webhookdb::Services::Column.new(:created_at, TIMESTAMP, index: true),
      Webhookdb::Services::Column.new(:open_rate, DECIMAL, from_enrichment: true, optional: true),
      Webhookdb::Services::Column.new(:progress, DECIMAL, from_enrichment: true, optional: true),
      Webhookdb::Services::Column.new(:recipients, INTEGER, from_enrichment: true, optional: true),
      Webhookdb::Services::Column.new(:show_total_clicks, BOOLEAN, from_enrichment: true, optional: true),
      Webhookdb::Services::Column.new(:status, TEXT, from_enrichment: true, optional: true),
      Webhookdb::Services::Column.new(:subject, TEXT),
      Webhookdb::Services::Column.new(:total_clicks, INTEGER, from_enrichment: true, optional: true),
      Webhookdb::Services::Column.new(:unsubscribes, INTEGER, from_enrichment: true, optional: true),
    ]
  end

  def _resource_and_event(request)
    return request.body, nil
  end

  def _timestamp_column_name
    return :created_at
  end

  def _update_where_expr
    return self.qualified_table_sequel_identifier[:data] !~ Sequel[:excluded][:data]
  end

  def _store_enrichment_body?
    return true
  end

  def _fetch_enrichment(resource, _event, _request)
    broadcast_id = resource.fetch("id")
    url = "https://api.convertkit.com/v3/broadcasts/#{broadcast_id}/stats?api_secret=#{self.service_integration.backfill_secret}"
    response = Webhookdb::Http.get(url, logger: self.logger)
    data = response.parsed_response
    return data.dig("broadcast", "stats") || {}
  end

  def _fetch_backfill_page(_pagination_token, **_kwargs)
    # this endpoint does not have pagination support
    url = "https://api.convertkit.com/v3/broadcasts?api_secret=#{self.service_integration.backfill_secret}"
    response = Webhookdb::Http.get(url, logger: self.logger)
    data = response.parsed_response
    return data["broadcasts"], nil
  end
end
