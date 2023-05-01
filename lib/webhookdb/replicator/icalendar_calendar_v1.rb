# frozen_string_literal: true

require "down"

require "webhookdb/jobs/icalendar_sync"

class Webhookdb::Replicator::IcalendarCalendarV1 < Webhookdb::Replicator::Base
  include Appydays::Loggable

  # @return [Webhookdb::Replicator::Descriptor]
  def self.descriptor
    return Webhookdb::Replicator::Descriptor.new(
      name: "icalendar_calendar_v1",
      ctor: ->(sint) { Webhookdb::Replicator::IcalendarCalendarV1.new(sint) },
      feature_roles: ["beta"],
      resource_name_singular: "iCalendar Calendar",
    )
  end

  def upsert_has_deps? = true

  def _webhook_response(request)
    return Webhookdb::WebhookResponse.for_standard_secret(request, self.service_integration.webhook_secret)
  end

  def calculate_create_state_machine
    return self.calculate_backfill_state_machine
  end

  def calculate_backfill_state_machine
    step = Webhookdb::Replicator::StateMachineStep.new
    if self.service_integration.webhook_secret.blank?
      self.service_integration.save_changes
      step.output = %(You are about to add support for syncing iCalendar (.ics) URLs into WebhookDB.

We have detailed instructions on this process
at https://webhookdb.com/docs/icalendar.

The first step is to generate a secret you will use for signing
API requests you send to WebhookDB. You can use '#{Webhookdb::Id.rand_enc(16)}'
or generate your own value.
Copy and paste or enter a new value, and press enter.)
      return step.secret_prompt("secret").webhook_secret(self.service_integration)
    end
    step.output = %(
All set! Here is the endpoint to send requests to
from your backend. Refer to https://webhookdb.com/docs/icalendar
for details on the format of the request:

#{self.webhook_endpoint}

The secret to use for signing is:

#{self.service_integration.webhook_secret}

#{self._query_help_output})
    return step.completed
  end

  def _remote_key_column
    return Webhookdb::Replicator::Column.new(:external_id, TEXT)
  end

  def _denormalized_columns
    return [
      Webhookdb::Replicator::Column.new(:row_created_at, TIMESTAMP, index: true, optional: true, defaulter: :now),
      Webhookdb::Replicator::Column.new(:row_updated_at, TIMESTAMP, index: true, optional: true, defaulter: :now),
      Webhookdb::Replicator::Column.new(:last_synced_at, TIMESTAMP, index: true, optional: true),
      Webhookdb::Replicator::Column.new(:ics_url, TEXT),
    ]
  end

  def _timestamp_column_name
    return :row_updated_at
  end

  def _resource_and_event(request)
    return request.body, nil
  end

  def _update_where_expr
    return self.qualified_table_sequel_identifier[:row_updated_at] < Sequel[:excluded][:row_updated_at]
  end

  def _upsert_update_expr(inserting, **_kwargs)
    update = super
    # Only set created_at if it's not set so the initial insert isn't modified.
    self._coalesce_excluded_on_update(update, [:row_created_at])
    return update
  end

  def _resource_to_data(resource, _event, _request)
    data = resource.dup
    # Remove the client-provided webhook fields.
    data.clear
    return data
  end

  def upsert_webhook(request)
    request_type = request.body.fetch("type")
    external_id = request.body.fetch("external_id")
    case request_type
      when "SYNC"
        super(request)
        Webhookdb::Jobs::IcalendarSync.perform_async(self.service_integration.id, external_id)
        return
      when "DELETE"
        relevant_integrations = self.service_integration.recursive_dependents.
          filter { |d| CLEANUP_SERVICE_NAMES.include?(d.service_name) }
        self.admin_dataset do |ds|
          ds.db.transaction do
            ds.where(external_id:).delete
            relevant_integrations.each do |sint|
              ds.db[sint.replicator.qualified_table_sequel_identifier].where(calendar_external_id: external_id).delete
            end
          end
        end
        return
      when "__WHDB_UNIT_TEST"
        unless Webhookdb::RACK_ENV == "test"
          raise "someone tried to use the special unit test google event type outside of unit tests"
        end
        return super(request)
      else
        raise ArgumentError, "Unknown request type: #{request_type}"
    end
  end

  CLEANUP_SERVICE_NAMES = ["icalendar_event_v1"].freeze
  SYNC_PERIOD = 4.hours

  def rows_needing_sync(dataset, now: Time.now)
    cutoff = now - SYNC_PERIOD
    return dataset.where(Sequel[last_synced_at: nil] | Sequel.expr { last_synced_at < cutoff })
  end

  class Upserter
    include Webhookdb::Backfiller::Bulk
    attr_reader :upserting_replicator

    def initialize(replicator, calendar_row)
      @upserting_replicator = replicator
      @calendar_external_id = calendar_row.fetch(:external_id)
    end

    def upsert_page_size = 500
    def conditional_upsert? = true

    def prepare_body(body)
      body["calendar_external_id"] = @calendar_external_id
    end
  end

  def sync_row(row)
    if (dep = self.find_dependent("icalendar_event_v1"))
      upserter = Upserter.new(dep.replicator, row)
      io = Down::NetHttp.open(row.fetch(:ics_url), rewindable: false)
      vevent_lines = []
      in_vevent = false
      while (line = io.gets)
        line.rstrip!
        if line == "BEGIN:VEVENT"
          in_vevent = true
          vevent_lines << line
        elsif line == "END:VEVENT"
          in_vevent = false
          vevent_lines << line
          h = Webhookdb::Replicator::IcalendarEventV1.vevent_to_hash(vevent_lines)
          vevent_lines.clear
          upserter.handle_item(h)
        elsif in_vevent
          vevent_lines << line
        end
      end
      upserter.flush_pending_inserts
    end
    self.admin_dataset { |ds| ds.where(pk: row.fetch(:pk)).update(last_synced_at: Time.now) }
  end

  private def gets(src)
    l = src.gets
    l&.chomp!
    return l
  end
end
