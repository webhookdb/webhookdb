# frozen_string_literal: true

require "webhookdb/brevo"
require "webhookdb/replicator/brevo_v1_mixin"

class Webhookdb::Replicator::BrevoEmailActivityUnaggregatedEventsV1 < Webhookdb::Replicator::Base
  include Appydays::Loggable
  include Webhookdb::Replicator::BrevoV1Mixin

  # API Reference: https://developers.brevo.com/reference/getemaileventreport-1
  # @return [Webhookdb::Replicator::Descriptor]
  def self.descriptor
    return Webhookdb::Replicator::Descriptor.new(
      name: "brevo_email_activity_unaggregated_events_v1",
      ctor: ->(sint) { self.new(sint) },
      feature_roles: [],
      resource_name_singular: "Transactional Email Activity (Unaggregated Events)",
      resource_name_plural: "Transactional Email Activity (Unaggregated Events)",
      supports_webhooks: true,
      supports_backfill: true,
      api_docs_url: "https://developers.brevo.com/reference",
    )
  end

  def _remote_key_column
    return Webhookdb::Replicator::Column.new(:email_activity_event_id, TEXT, data_key: "messageId")
  end

  # This returns a union of all webhook schemas, defined in https://developers.brevo.com/docs/transactional-webhooks.
  # The backfill API endpoint (https://api.brevo.com/v3/smtp/statistics/events) only returns a subset of these.
  def _denormalized_columns
    return [
      Webhookdb::Replicator::Column.new(:event, TEXT, index: true),
      Webhookdb::Replicator::Column.new(:email, TEXT),
      Webhookdb::Replicator::Column.new(
        :date,
        TIMESTAMP,
        data_key: "date",
        defaulter: :now,
        index: true,
        converter: Webhookdb::Replicator::Column::CONV_PARSE_TIME,
      ),
      Webhookdb::Replicator::Column.new(
        :message_id,
        TEXT,
        data_key: "messageId",
        index: true,
      ),
    ]
  end

  def _update_where_expr
    return self.qualified_table_sequel_identifier[:date] < Sequel[:excluded][:date]
  end

  def _resource_and_event(request)
    return request.body, nil
  end

  def _mixin_backfill_url
    # API  Reference: https://developers.brevo.com/reference/getemaileventreport-1
    return "#{self.service_integration.api_url}/smtp/statistics/events"
  end
end
