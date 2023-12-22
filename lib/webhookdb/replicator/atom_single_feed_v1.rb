# frozen_string_literal: true

require "down"

require "webhookdb/xml"

class Webhookdb::Replicator::AtomSingleFeedV1 < Webhookdb::Replicator::Base
  include Appydays::Loggable

  # @return [Webhookdb::Replicator::Descriptor]
  def self.descriptor
    return Webhookdb::Replicator::Descriptor.new(
      name: "atom_single_feed_v1",
      ctor: ->(sint) { Webhookdb::Replicator::AtomSingleFeedV1.new(sint) },
      feature_roles: [],
      resource_name_singular: "Single Atom Feed",
      supports_backfill: true,
      description: "Convert any Atom XML feed into a database table for querying and persistent archiving.",
      api_docs_url: "https://en.wikipedia.org/wiki/Atom_(web_standard)",
    )
  end

  def _remote_key_column
    return Webhookdb::Replicator::Column.new(:entry_id, TEXT, data_key: "id")
  end

  CONV_GEO_LAT = Webhookdb::Replicator::Column.converter_array_element(index: 0, sep: " ", cls: DECIMAL)
  CONV_GEO_LNG = Webhookdb::Replicator::Column.converter_array_element(index: 1, sep: " ", cls: DECIMAL)

  def _denormalized_columns
    col = Webhookdb::Replicator::Column
    return [
      col.new(:row_created_at, TIMESTAMP, index: true, optional: true, defaulter: :now),
      col.new(:updated, TIMESTAMP, index: true),
      col.new(:title, TEXT),
      col.new(:published, TIMESTAMP, index: true, optional: true),
      col.new(:geo_lat, DECIMAL, data_key: "georss:point", optional: true, converter: CONV_GEO_LAT),
      col.new(:geo_lng, DECIMAL, data_key: "georss:point", optional: true, converter: CONV_GEO_LNG),
    ]
  end

  def _timestamp_column_name
    return :updated
  end

  def _resource_and_event(request)
    return request.body, nil
  end

  def _update_where_expr
    return self.qualified_table_sequel_identifier[:updated] < Sequel[:excluded][:updated]
  end

  def _upsert_update_expr(inserting, **_kwargs)
    update = super
    # Only set created_at if it's not set so the initial insert isn't modified.
    self._coalesce_excluded_on_update(update, [:row_created_at])
    return update
  end

  def _fetch_backfill_page(*)
    io = Webhookdb::Http.get(self.service_integration.api_url, logger: self.logger, timeout: 30)
    feed_obj = Webhookdb::Xml::Atom.parse(io.body)
    return feed_obj.fetch("entries"), nil
  end

  def _verify_backfill_err_msg
    return "Sorry, we can't reach that URL. Please double check it and try again."
  end

  def _backfillers
    return [Backfiller.new(self)]
  end

  class Backfiller < Webhookdb::Replicator::Base::ServiceBackfiller
    include Webhookdb::Backfiller::Bulk
    attr_reader :upserting_replicator

    def initialize(replicator)
      super
      @upserting_replicator = @svc
    end

    def upsert_page_size = 500
    def conditional_upsert? = true
    def prepare_body(body) = body
  end

  def _webhook_response(_request)
    return Webhookdb::WebhookResponse.ok
  end

  def calculate_backfill_state_machine
    step = Webhookdb::Replicator::StateMachineStep.new
    # Must set this to fake out having credentials.
    self.service_integration.update(backfill_key: "placeholder") if self.service_integration.backfill_key.blank?
    if self.service_integration.api_url.blank?
      step.output = %(You're about to sync entries from an Atom URL into WebhookDB.
This will create a row for each 'entry' in the given feed,
and insert/update new rows periodically.

Paste in the URL to sync, and press Enter.)
      return step.prompting("URL").api_url(self.service_integration)
    end
    unless (result = self.verify_backfill_credentials).verified
      self.service_integration.update(api_url: "")
      step.output = result.message
      return step.prompting("URL").api_url(self.service_integration)
    end
    step.output = %(
All set! Your feed will be synced momentarily and then every few hours after that.

#{self._query_help_output})
    return step.completed
  end
end
