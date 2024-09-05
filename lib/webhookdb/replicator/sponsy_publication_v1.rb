# frozen_string_literal: true

require "webhookdb/replicator/sponsy_v1_mixin"

class Webhookdb::Replicator::SponsyPublicationV1 < Webhookdb::Replicator::Base
  include Appydays::Loggable
  include Webhookdb::Replicator::SponsyV1Mixin

  def self.descriptor
    return Webhookdb::Replicator::Descriptor.new(
      name: "sponsy_publication_v1",
      ctor: self,
      feature_roles: [],
      resource_name_singular: "Sponsy Publication",
      supports_backfill: true,
      api_docs_url: "https://api.getsponsy.com/docs",
    )
  end

  def _denormalized_columns
    col = Webhookdb::Replicator::Column
    return [
      col.new(:name, TEXT),
      col.new(:slug, TEXT),
      col.new(:type, TEXT),
      col.new(:deleted_at, TIMESTAMP, optional: true),
      col.new(
        :days,
        INTEGER_ARRAY,
        converter: col.converter_map_lookup(
          array: true,
          # 'MONDAY' => 0, 0 defaults to 0
          map: col::DAYS_OF_WEEK.rotate.each_with_index.to_h { |dow, idx| [dow, idx] },
        ),
      ),
      col.new(
        :days_normalized,
        INTEGER_ARRAY,
        data_key: "days",
        converter: col.converter_map_lookup(
          array: true,
          # 'MONDAY' => 1, 0 => 1
          map: col::DAYS_OF_WEEK.each_with_index.to_a.concat((0..6).zip((0..6).to_a.rotate)).to_h,
        ),
        backfill_statement: Sequel.lit(<<~SQL),
          CREATE OR REPLACE FUNCTION pg_temp.sponsy_publication_v1_normalize_days(integer[])
            RETURNS integer[] AS 'SELECT ARRAY(SELECT ((n + 1) % 7) FROM unnest($1) AS n)' LANGUAGE sql IMMUTABLE
        SQL
        backfill_expr: Sequel.lit("pg_temp.sponsy_publication_v1_normalize_days(days)"),
      ),
      col.new(
        :day_names,
        TEXT_ARRAY,
        data_key: "days",
        converter: col.converter_map_lookup(
          array: true,
          # 0 => 'MONDAY'
          map: col::DAYS_OF_WEEK.rotate.each_with_index.to_h { |dow, idx| [idx, dow] },
        ),
        # Big switch statement to map dow number to name
        backfill_statement: Sequel.lit(<<~SQL),
          CREATE OR REPLACE FUNCTION pg_temp.sponsy_publication_v1_day_names(integer[])
            RETURNS text[] AS 'SELECT ARRAY(SELECT (CASE WHEN n = 0 THEN ''MONDAY'' WHEN n = 1 THEN ''TUESDAY'' WHEN n = 2 THEN ''WEDNESDAY'' WHEN n = 3 THEN ''THURSDAY'' WHEN n = 4 THEN ''FRIDAY'' WHEN n = 5 THEN ''SATURDAY'' WHEN n = 6 THEN ''SUNDAY'' END) FROM unnest($1) AS n)' LANGUAGE sql IMMUTABLE
        SQL
        backfill_expr: Sequel.lit("pg_temp.sponsy_publication_v1_day_names(days)"),
      ),
    ].concat(self._ts_columns)
  end

  def _backfillers
    return [Backfiller.new(self)]
  end

  def _fetch_backfill_page(pagination_token, last_backfilled:)
    return self.fetch_sponsy_page("/v1/publications", pagination_token, last_backfilled)
  end

  def calculate_backfill_state_machine
    step = Webhookdb::Replicator::StateMachineStep.new
    unless self.service_integration.backfill_secret.present?
      step.needs_input = true
      step.output = %(Great! Let's work on your Sponsy Publications integration.

Head over to your Sponsy dashboard and copy your API key:

https://getsponsy.com/settings/workspace
)
      return step.secret_prompt("API key").backfill_secret(self.service_integration)
    end

    unless (result = self.verify_backfill_credentials).verified
      self.service_integration.replicator.clear_backfill_information
      step.output = result.message
      return step.secret_prompt("API Key").backfill_secret(self.service_integration)
    end

    step.output = %(We are going to start replicating your Sponsy Publications
and will keep them updated. You can can also add more Sponsy integrations.
Run `webhookdb services list` to see what's available.
#{self._query_help_output}
)
    return step.completed
  end

  def _verify_backfill_401_err_msg
    return "It looks like that API Key is invalid. Head back to https://getsponsy.com/settings/workspace, " \
           "copy the API key, and try again:"
  end

  # Normal backfiller that keeps track of inserted items,
  # and marks anything not backfilled as deleted.
  class Backfiller < Webhookdb::Replicator::Base::ServiceBackfiller
    def handle_item(item)
      super
      @seen_ids ||= []
      @seen_ids << item.fetch("id")
    end

    def flush_pending_inserts
      self.svc.admin_dataset do |ds|
        ds = Webhookdb::Dbutil.where_not_in_using_index(ds, :sponsy_id, @seen_ids)
        ds = ds.where(deleted_at: nil)
        ds.update(deleted_at: Sequel.function(:now))
      end
    end
  end
end
