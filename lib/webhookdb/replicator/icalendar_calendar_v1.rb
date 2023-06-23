# frozen_string_literal: true

require "down"
require "ice_cube"

require "webhookdb/messages/error_icalendar_fetch"

require "webhookdb/jobs/icalendar_sync"

class Webhookdb::Replicator::IcalendarCalendarV1 < Webhookdb::Replicator::Base
  include Appydays::Loggable

  RECURRENCE_PROJECTION = 5.years

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
    col = Webhookdb::Replicator::Column
    return [
      col.new(:row_created_at, TIMESTAMP, index: true, optional: true, defaulter: :now),
      col.new(:row_updated_at, TIMESTAMP, index: true, optional: true, defaulter: :now),
      col.new(:last_synced_at, TIMESTAMP, index: true, optional: true),
      col.new(:ics_url, TEXT, converter: col.converter_gsub(/^webcal/, "https")),
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
    attr_reader :upserting_replicator, :calendar_external_id

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
      calendar_external_id = upserter.calendar_external_id
      request_url = row.fetch(:ics_url)
      begin
        io = Down::NetHttp.open(request_url, rewindable: false)
      rescue Down::ClientError => e
        raise e if e.response.nil?
        response_status = e.response.code.to_i
        raise e if response_status > 404 || response_status < 400
        response_body = e.response.body.to_s
        self.logger.warn("icalendar_fetch_error",
                         response_body:, response_status:, request_url:, calendar_external_id:,)
        message = Webhookdb::Messages::ErrorIcalendarFetch.new(
          self.service_integration,
          calendar_external_id,
          response_status:,
          response_body:,
          request_url:,
          request_method: "GET",
        )
        self.service_integration.organization.alerting.dispatch_alert(message)
        return
      end
      # Keep track of everything we upsert. For any rows we aren't upserting,
      # delete them if they're recurring, or cancel them if they're not recurring.
      # If doing it this way is slow, we could invert this (pull down all IDs and pop from the set).
      upserted_identities = []

      # Keep track of all upserted recurring items.
      # If we find a RECURRENCE-ID on a later item,
      # we need to modify the item from the sequence by stealing its compound identity.
      upserted_recurring_items_by_uid = {}

      # Delete recurring event rows that we know are not going to be updated.
      # Whenever we project a recurring event, we keep track of how many entries
      # will be projected. We delete any entries beyond this.
      delete_conds = []

      self.class.each_event(io) do |ical_ev_hash|
        # Add each event hash to pending upserts, and keep track of it for cancelation.
        recur_result = self._expand_recurrence(ical_ev_hash, upserted_recurring_items_by_uid) do |ev|
          ident, upserted = upserter.handle_item(ev)
          upserted_identities << ident
          if (recurring_uid = upserted.fetch(:recurring_event_id))
            upserted_recurring_items_by_uid[recurring_uid] ||= []
            upserted_recurring_items_by_uid[recurring_uid] << upserted
          end
        end
        if (delete_cond = recur_result[:delete_cond])
          delete_conds << delete_cond
        end
      end
      upserter.flush_pending_inserts
      # Delete all the extra replicator rows, and cancel all the rows that weren't upserted.
      dep.replicator.admin_dataset do |ds|
        ds = ds.where(calendar_external_id:)
        ds.where(delete_conds.inject(&:|)).delete unless delete_conds.empty?
        # Update both the status, and set the data json to match.
        ds.exclude(compound_identity: upserted_identities).update(
          status: "CANCELLED",
          data: Sequel.lit('data || \'{"STATUS":{"v":"CANCELLED"}}\'::jsonb'),
        )
      end
    end
    self.admin_dataset { |ds| ds.where(pk: row.fetch(:pk)).update(last_synced_at: Time.now) }
  end

  private def gets(src)
    l = src.gets
    l&.chomp!
    return l
  end

  private def _expand_recurrence(h, upserted_recurring_items_by_uid)
    raise LocalJumpError unless block_given?

    uid = h.fetch("UID").fetch("v")
    recur_result = {}

    if (recurrence_id = h["RECURRENCE-ID"])
      # Track down the original item in the projected sequence, so we can update it.
      if (start = Webhookdb::Replicator::IcalendarEventV1.entry_to_datetime(recurrence_id))
        startfield = :start_at
      elsif (start = Webhookdb::Replicator::IcalendarEventV1.entry_to_date(recurrence_id))
        startfield = :start_date
      else
        raise ArgumentError, "invalid recurrence-id: #{recurrence_id}"
      end
      candidates = upserted_recurring_items_by_uid.fetch(uid)
      unless (match = candidates.find { |c| c[startfield] == start })
        # If there's no matching event that we're overriding, log a warning.
        # It could be far in the future. The worst case here is is that we will
        # have a standalone event, which is sort of the point.
        self.logger.warn("icalendar_recurrence_id_missing", vevent: h)
        Sentry.with_scope do |scope|
          scope.set_extras(vevent: h)
          Sentry.capture_message("icalendar_recurrence_id_missing")
        end
        yield h
        return recur_result
      end

      # Steal the UID to overwrite the original, and record where it came from.
      # Note that all other fields, like categories, will be overwritten with the fields in this exclusion.
      # This seems to be correct, but we should keep an eye open in case we need to merge
      # these exclusion events into the originals.
      h["UID"] = {"v" => match[:uid]}
      h["recurring_event_sequence"] = match[:recurring_event_sequence]
      # Usually the recurrent event and exclusion have the same last-modified.
      # But we need to set the last-modified to AFTER the original,
      # to make sure it replaces what's in the database (the original un-excluded event
      # may already be present in the database).
      h["LAST-MODIFIED"] = match.fetch(:last_modified_at) + 1.second
      yield h
      return recur_result
    end

    unless h["RRULE"]
      yield h
      return recur_result
    end

    # We need to convert relevant parsed ical lines back to a string for use in ice_cube.
    # There are other ways to handle this, but this is fine for now.
    ical_params = {}
    # These are taken from ice_cube ical_parser
    ["RDATE", "EXDATE", "DURATION", "RRULE"].each do |propname|
      ical_params[propname] = h[propname] if h[propname]
    end

    start_entry = h.fetch("DTSTART")
    ev_replicator = Webhookdb::Replicator::IcalendarEventV1
    # Use actual Times for start/end since ice_cube doesn't parse them well
    ical_params["DTSTART"] = ev_replicator::CONV_DATETIME.ruby.call(start_entry) ||
      ev_replicator::CONV_DATE.ruby.call(start_entry)
    has_end_time = false
    if (end_entry = h["DTEND"])
      # the end date is optional. If we don't have one, we should never store one.
      has_end_time = true
      ical_params["DTEND"] = ev_replicator::CONV_DATETIME.ruby.call(end_entry) ||
        ev_replicator::CONV_DATE.ruby.call(end_entry)
    end

    schedule = IceCube::Schedule.from_ical(self._unexplode_ical(ical_params))
    formatter = ical_params["DTSTART"].is_a?(Date) ? :_format_date : :_format_datetime
    # Don't project events further out than this
    closing_time = Time.now + RECURRENCE_PROJECTION
    # Just like google, track the original event id.
    h["recurring_event_id"] = uid
    final_sequence = -1
    schedule.send(:enumerate_occurrences, schedule.start_time).each_with_index do |occ, idx|
      # Given the original hash, we will modify some fields.
      e = h.dup
      # Keep track of how many events we're managing.
      e["recurring_event_sequence"] = idx
      # The new UID has the sequence number.
      e["UID"] = {"v" => "#{uid}-#{idx}"}
      e["DTSTART"] = {"v" => self.send(formatter, occ.start_time)}
      e["DTEND"] = {"v" => self.send(formatter, occ.end_time)} if has_end_time
      yield e
      final_sequence = idx
      break if occ.start_time > closing_time
    end
    # If we're now projecting fewer rows, we need to clean up the ones we no longer update.
    recur_result[:delete_cond] = Sequel[recurring_event_id: uid] & (Sequel[:recurring_event_sequence] > final_sequence)
    return recur_result
  end

  def _format_datetime(t)
    return t.utc.strftime("%Y%m%dT%H%M%SZ")
  end

  def _format_date(d)
    return d.strftime("%Y%m%d")
  end

  # This is not entirely safe (double quotes, multiple lines), but it's fine for date use.
  def _unexplode_ical(ical_hash)
    lines = []
    ical_hash.each do |k, h|
      s = +k.to_s
      if h.is_a?(Time)
        s << ":#{self._format_datetime(h)}"
      elsif h.is_a?(Date)
        s << ":#{self._format_date(h)}"
      else
        h = h.dup
        value = h.delete("v")
        h.each do |hk, hv|
          s << ";#{hk}=#{hv}"
        end
        s << ":#{value}"
      end
      lines << s
    end
    return lines.join("\r\n")
  end

  def self.each_event(io)
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
        yield h
      elsif in_vevent
        vevent_lines << line
      end
    end
  end
end
