# frozen_string_literal: true

class Webhookdb::Replicator::BrevoEmailActivityUnaggregatedEventsV1 < Webhookdb::Replicator::Base
  include Appydays::Loggable

  # @return [Webhookdb::Replicator::Descriptor]
  def self.descriptor
    return Webhookdb::Replicator::Descriptor.new(
      name: "brevo_email_aggregated_per_day_v1",
      ctor: ->(sint) { self.new(sint) },
      feature_roles: [],
      resource_name_singular: "Transactional Email Activity (Unaggregated Events)",
      supports_webhooks: true,
      supports_backfill: true,
      api_docs_url: "https://developers.brevo.com/reference",
    )
  end

  def _remote_key_column
    Webhookdb::Replicator::Column.new(:email_activity_event_id, TEXT, data_key: "messageId")
  end

  def _denormalized_columns
    [
      Webhookdb::Replicator::Column.new(:email, TEXT, index: true),
      Webhookdb::Replicator::Column.new(
        :date,
        TIMESTAMP,
        data_key: "date",
        defaulter: :now,
        index: true,
      ),
      Webhookdb::Replicator::Column.new(:subject, TEXT, index: true),
      Webhookdb::Replicator::Column.new(:event, TEXT),
      Webhookdb::Replicator::Column.new(:tag, TEXT),
      Webhookdb::Replicator::Column.new(:reason, TEXT),
      Webhookdb::Replicator::Column.new(:link, TEXT),
      Webhookdb::Replicator::Column.new(:ip, TEXT),
      Webhookdb::Replicator::Column.new(:from, TEXT),
      Webhookdb::Replicator::Column.new(:templateId, BIGINT),
    ]
  end

  def _update_where_expr
    self.qualified_table_sequel_identifier[:date] < Sequel[:excluded][:date]
  end

  def _timestamp_column_name = :date
end
