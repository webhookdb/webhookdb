# frozen_string_literal: true

require "down"
require "ice_cube"

require "webhookdb/icalendar"
require "webhookdb/jobs/icalendar_sync"
require "webhookdb/messages/error_icalendar_fetch"

class Webhookdb::Replicator::IcalendarCalendarV1 < Webhookdb::Replicator::Base
  include Appydays::Loggable

  RECURRENCE_PROJECTION = 5.years

  def documentation_url = Webhookdb::Icalendar::DOCUMENTATION_URL

  # @return [Webhookdb::Replicator::Descriptor]
  def self.descriptor
    return Webhookdb::Replicator::Descriptor.new(
      name: "icalendar_calendar_v1",
      ctor: ->(sint) { Webhookdb::Replicator::IcalendarCalendarV1.new(sint) },
      feature_roles: [],
      resource_name_singular: "iCalendar Calendar",
      supports_webhooks: true,
      description: "Fetch and convert an icalendar format file into a schematized and queryable database table.",
      api_docs_url: "https://icalendar.org/",
    )
  end

  def upsert_has_deps? = true

  def _webhook_response(request)
    return Webhookdb::WebhookResponse.for_standard_secret(request, self.service_integration.webhook_secret)
  end

  def calculate_webhook_state_machine
    step = Webhookdb::Replicator::StateMachineStep.new
    if self.service_integration.webhook_secret.blank?
      self.service_integration.save_changes
      step.output = %(You are about to add support for replicating iCalendar (.ics) URLs into WebhookDB.

We have detailed instructions on this process
at https://docs.webhookdb.com/guides/icalendar/.

The first step is to generate a secret you will use for signing
API requests you send to WebhookDB. You can use '#{Webhookdb::Id.rand_enc(16)}'
or generate your own value.
Copy and paste or enter a new value, and press enter.)
      return step.secret_prompt("secret").webhook_secret(self.service_integration)
    end
    step.output = %(
All set! Here is the endpoint to send requests to
from your backend. Refer to https://docs.webhookdb.com/guides/icalendar/
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
      col.new(:ics_url, TEXT, converter: col.converter_gsub("^webcal", "https")),
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

  def _resource_to_data(resource, *)
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
        self.delete_data_for_external_id(external_id)
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

  def rows_needing_sync(dataset, now: Time.now)
    cutoff = now - Webhookdb::Icalendar.sync_period_hours.hours
    return dataset.where(Sequel[last_synced_at: nil] | Sequel.expr { last_synced_at < cutoff })
  end

  def delete_data_for_external_id(external_id)
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
  end

  class Upserter
    include Webhookdb::Backfiller::Bulk
    attr_reader :upserting_replicator, :calendar_external_id, :now

    def initialize(replicator, calendar_external_id, now:)
      @upserting_replicator = replicator
      @calendar_external_id = calendar_external_id
      @now = now
    end

    def upsert_page_size = 500
    def conditional_upsert? = true

    def prepare_body(body)
      body["calendar_external_id"] = @calendar_external_id
      body["row_updated_at"] = @now
    end
  end

  def sync_row(row)
    Appydays::Loggable.with_log_tags(icalendar_url: row.fetch(:ics_url)) do
      self.with_advisory_lock(row.fetch(:pk)) do
        now = Time.now
        if (dep = self.find_dependent("icalendar_event_v1"))
          self._sync_row(row, dep, now:)
        end
        self.admin_dataset { |ds| ds.where(pk: row.fetch(:pk)).update(last_synced_at: now) }
      end
    end
  end

  def _sync_row(row, dep, now:)
    calendar_external_id = row.fetch(:external_id)
    begin
      request_url = self._clean_ics_url(row.fetch(:ics_url))
      io = Webhookdb::Http.chunked_download(request_url, rewindable: false)
    rescue Down::Error, URI::InvalidURIError => e
      self._handle_down_error(e, request_url:, calendar_external_id:)
      return
    end

    upserter = Upserter.new(dep.replicator, calendar_external_id, now:)
    processor = EventProcessor.new(io, upserter)
    processor.process
    # Delete all the extra replicator rows, and cancel all the rows that weren't upserted.
    dep.replicator.admin_dataset do |ds|
      ds = ds.where(calendar_external_id:)
      if (delete_condition = processor.delete_condition)
        ds.where(delete_condition).delete
      end
      # Update both the status, and set the data json to match.
      # Only update rows not already CANCELLED.
      ds = ds.exclude(Sequel[compound_identity: processor.upserted_identities])
      ds = ds.where(Sequel[status: nil] | ~Sequel[status: "CANCELLED"])
      ds.update(
        status: "CANCELLED",
        data: Sequel.lit('data || \'{"STATUS":{"v":"CANCELLED"}}\'::jsonb'),
        row_updated_at: now,
      )
    end
  end

  # We get all sorts of strange urls, fix up what we can.
  def _clean_ics_url(url)
    u = URI(url)
    # https://xyz.com:80 is invalid, set it to 443 which yields https://xyz.com
    u.port = 443 if u.scheme == "https" && u.port == 80
    return u.to_s
  end

  def _handle_down_error(e, request_url:, calendar_external_id:)
    case e
      when Down::TooManyRedirects
        response_status = 301
        response_body = "<too many redirects>"
      when Down::NotModified
        # Do not alert on 304, but do log
        self.logger.info("icalendar_fetch_not_modified", response_status: 304, request_url:, calendar_external_id:)
        return
      when Down::SSLError
        # Most SSL errors are transient and can be retried, but some are due to a long-term misconfiguration.
        # Handle these with an alert, like if we had a 404, which indicates a longer-term issue.
        is_fatal =
          # There doesn't appear to be a way to allow unsafe legacy content negotiation on a per-request basis,
          # it is compiled into OpenSSL (may be wrong about this).
          e.to_s.include?("unsafe legacy renegotiation disabled") ||
          # Certificate failures are not transient
          e.to_s.include?("certificate verify failed")
        if is_fatal
          response_status = 0
          response_body = e.to_s
        else
          self._handle_retryable_down_error!(e, request_url:, calendar_external_id:)
        end
      when Down::TimeoutError, Down::ConnectionError, Down::InvalidUrl, URI::InvalidURIError
        response_status = 0
        response_body = e.to_s
      when Down::ClientError
        raise e if e.response.nil?
        response_status = e.response.code.to_i
        self._handle_retryable_down_error!(e, request_url:, calendar_external_id:) if
          self._retryable_client_error?(e, request_url:)
        # These are all the errors we've seen, we can't do anything about.
        # In theory we should do this for ALL 4xx errors,
        # but we'd rather error on the WebhookDB side until we're sure
        # we want to ignore things.
        expected_errors = [
          400, 401, 402, 403, # Common access problems we can't do anything about
          404, 405, # Fundamental issues with the URL given
          409, 410, # More access problems
          417, # If someone uses an Outlook HTML calendar, fetch gives us a 417
          429, # Usually 429s are retried (as above), but in some cases they're not.
        ]
        # For most client errors, we can't do anything about it. For example,
        # and 'unshared' URL could result in a 401, 403, 404, or even a 405.
        # For now, other client errors, we can raise on,
        # in case it's something we can fix/work around.
        # For example, it's possible something like a 415 is a WebhookDB issue.
        raise e unless expected_errors.include?(response_status)
        response_body = e.response.body.to_s
      when Down::ServerError
        response_status = e.response.code.to_i
        response_body = e.response.body.to_s
      else
        response_body = nil
        response_status = nil
    end
    raise e if response_status.nil?
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
  end

  def _retryable_client_error?(e, request_url:)
    code = e.response.code.to_i
    # This is a bad domain that returns 429 for most requests.
    # Tell the org admins it won't sync.
    return false if code == 429 && request_url.start_with?("https://ical.schedulestar.com")
    # Other 429s can be retried.
    return true if code == 429
    # Otherwise, handle the client error normally, by telling the org admins, or raising.
    return false
  end

  def _handle_retryable_down_error!(e, request_url:, calendar_external_id:)
    # Retry on these, which are hopefully transient.
    # For now, if they aren't transient, die so we see the job.
    # We will probably need to do an alert if the retries on exhausted instead.
    retry_in = rand(4..60).minutes
    self.logger.debug(
      "icalendar_fetch_error_retry",
      response_status: e.respond_to?(:response) ? e.response&.code : 0,
      request_url:,
      calendar_external_id:,
      retry_at: Time.now + retry_in,
    )
    raise Amigo::Retry::OrDie.new(10, retry_in)
  end

  class EventProcessor
    attr_reader :upserted_identities

    def initialize(io, upserter)
      @io = io
      @upserter = upserter
      # Keep track of everything we upsert. For any rows we aren't upserting,
      # delete them if they're recurring, or cancel them if they're not recurring.
      # If doing it this way is slow, we could invert this (pull down all IDs and pop from the set).
      @upserted_identities = []
      # Keep track of all upserted recurring items.
      # If we find a RECURRENCE-ID on a later item,
      # we need to modify the item from the sequence by stealing its compound identity.
      @expanded_events_by_uid = {}
      # Delete 'extra' recurring event rows.
      # We need to keep track of how many events each UID spawns,
      # so we can delete any with a higher count.
      @max_sequence_num_by_uid = {}
    end

    def delete_condition
      return nil if @max_sequence_num_by_uid.empty?
      return @max_sequence_num_by_uid.map do |uid, n|
        Sequel[recurring_event_id: uid] & (Sequel[:recurring_event_sequence] > n)
      end.inject(&:|)
    end

    def process
      self.each_feed_event do |feed_event|
        self.each_projected_event(feed_event) do |ev|
          ident, upserted = @upserter.handle_item(ev)
          @upserted_identities << ident
          if (recurring_uid = upserted.fetch(:recurring_event_id))
            @expanded_events_by_uid[recurring_uid] ||= []
            @expanded_events_by_uid[recurring_uid] << upserted
          end
        end
      end
      @upserter.flush_pending_inserts
    end

    def each_projected_event(h)
      raise LocalJumpError unless block_given?

      uid = h.fetch("UID").fetch("v")

      if (recurrence_id = h["RECURRENCE-ID"])
        # Track down the original item in the projected sequence, so we can update it.
        if Webhookdb::Replicator::IcalendarEventV1.value_is_date_str?(recurrence_id.fetch("v"))
          start = Webhookdb::Replicator::IcalendarEventV1.entry_to_date(recurrence_id)
          startfield = :start_date
        else
          startfield = :start_at
          start = Webhookdb::Replicator::IcalendarEventV1.entry_to_datetime(recurrence_id).first
        end
        candidates = @expanded_events_by_uid[uid]
        if candidates.nil?
          # We can have no recurring events, even with the exclusion date.
          # Not much we can do here- just treat it as a standalone event.
          yield h
          return
        end
        unless (match = candidates.find { |c| c[startfield] == start })
          # There are some providers (like Apple) where an excluded event
          # will be outside the bounds of the RRULE of its owner.
          # Usually the RRULE has an UNTIL that is before the RECURRENCE-ID datetime.
          #
          # In these cases, we can use the event as-is, but we need to
          # make sure it is treated as part of the sequence.
          # So increment the last-seen sequence number for the UID and use that.
          max_seq_num = @max_sequence_num_by_uid[uid] += 1
          h["UID"] = {"v" => "#{uid}-#{max_seq_num}"}
          h["recurring_event_id"] = uid
          h["recurring_event_sequence"] = max_seq_num
          yield h
          return
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
        return
      end

      unless h["RRULE"]
        yield h
        return
      end

      # We need to convert relevant parsed ical lines back to a string for use in ice_cube.
      # There are other ways to handle this, but this is fine for now.
      ical_params = {}
      if (exdates = h["RDATE"])
        ical_params[:rtimes] = exdates.map { |d| self._time_array(d) }.flatten
      end
      if (exdates = h["EXDATE"])
        ical_params[:extimes] = exdates.map { |d| self._time_array(d) }.flatten
      end
      ical_params[:rrules] = [self._icecube_rule_from_ical(h["RRULE"]["v"])] if h["RRULE"]
      # DURATION is not supported

      start_entry = h.fetch("DTSTART")
      ev_replicator = Webhookdb::Replicator::IcalendarEventV1
      is_date = ev_replicator.entry_is_date_str?(start_entry)
      # Use actual Times for start/end since ice_cube doesn't parse them well
      ical_params[:start_time] = ev_replicator.entry_to_date_or_datetime(start_entry).first
      if ical_params[:start_time].year < 1000
        # This is almost definitely a misconfiguration. Yield it as non-recurring and move on.
        yield h
        return
      end
      has_end_time = false
      if (end_entry = h["DTEND"])
        # the end date is optional. If we don't have one, we should never store one.
        has_end_time = true
        ical_params[:end_time] = ev_replicator.entry_to_date_or_datetime(end_entry).first
        if ical_params[:end_time] < ical_params[:start_time]
          # This is an invalid event. Not sure what it'll do to IceCube so don't send it there.
          # Yield it as a non-recurring event and move on.
          yield h
          return
        end
      end

      schedule = IceCube::Schedule.from_hash(ical_params)
      dont_project_before = Webhookdb::Icalendar.oldest_recurring_event
      dont_project_after = @upserter.now + RECURRENCE_PROJECTION

      # Just like google, track the original event id.
      h["recurring_event_id"] = uid
      final_sequence = -1
      begin
        # Pass in a 'closing time' to avoid a denial of service for an impossible rrule.
        # It is further into the future than the "don't project after"
        # since using something too short causes the calculation to be short-circuited before it should
        # (I'm unclear what the ideal value is, but tests will fail with much less than the number here).
        # This still results in a slow calculation, but there's not much we can do for now.
        # In the future perhaps we should try to pre-validate common problems.
        # See spec for examples.
        dos_cutoff = dont_project_after + 210.days
        schedule.send(:enumerate_occurrences, schedule.start_time, dos_cutoff).each_with_index do |occ, idx|
          next if occ.start_time < dont_project_before
          # Given the original hash, we will modify some fields.
          e = h.dup
          # Keep track of how many events we're managing.
          e["recurring_event_sequence"] = idx
          # The new UID has the sequence number.
          e["UID"] = {"v" => "#{uid}-#{idx}"}
          e["DTSTART"] = self._ical_entry_from_ruby(occ.start_time, start_entry, is_date)
          e["DTEND"] = self._ical_entry_from_ruby(occ.end_time, end_entry, is_date) if has_end_time
          yield e
          final_sequence = idx
          break if occ.start_time > dont_project_after
        end
      rescue Date::Error
        # It's possible we yielded some recurring events too, in that case, treat them as normal,
        # in addition to yielding the event as non-recurring.
        yield h
      end
      @max_sequence_num_by_uid[uid] = final_sequence
      return
    end

    # We need is_date because the recurrence/IceCube schedule may be using times, not date.
    def _ical_entry_from_ruby(r, entry, is_date)
      return {"v" => r.strftime("%Y%m%d")} if is_date
      return {"v" => r.strftime("%Y%m%dT%H%M%SZ")} if r.zone == "UTC"
      tzid = entry["TZID"]
      return {"v" => r.strftime("%Y%m%dT%H%M%S"), "TZID" => tzid} if tzid
      value = entry.fetch("v")
      return {"v" => value} if value.end_with?("Z")
      raise "Cannot create ical entry from: #{r}, #{entry}, is_date: #{is_date}"
    end

    def _icecube_rule_from_ical(ical)
      # We have seen certain ambiguous rules, like FREQ=WEEKLY with BYMONTHDAY=4.
      # Apple interprets this as every 2 weeks; rrule.js interprets it as on the 4th of the month.
      # IceCube errors, because `day_of_month` isn't valid on a WeeklyRule.
      # In this case, we need to sanitize the string to remove the offending rule piece.
      # There are probably many other offending formats, but we'll add them here as needed.
      unambiguous_ical = nil
      if ical.include?("FREQ=WEEKLY") && ical.include?("BYMONTHDAY=")
        unambiguous_ical = ical.gsub(/BYMONTHDAY=[\d,]+/, "")
      elsif ical.include?("FREQ=MONTHLY") && ical.include?("BYYEARDAY=") && ical.include?("BYMONTHDAY=")
        # Another rule: FREQ=MONTHLY;INTERVAL=3;BYYEARDAY=14;BYMONTHDAY=14
        # Apple interprets this as monthly on the 14th; rrule.js interprets this as never happening.
        # 'day_of_year' isn't valid on a MonthlyRule, so delete the BYYEARDAY component.
        unambiguous_ical = ical.gsub(/BYYEARDAY=[\d,]+/, "")
      end
      if unambiguous_ical
        unambiguous_ical.delete_prefix! ";"
        unambiguous_ical.delete_suffix! ";"
        unambiguous_ical.squeeze!(";")
        ical = unambiguous_ical
      end
      return IceCube::IcalParser.rule_from_ical(ical)
    end

    def _time_array(h)
      expanded_entries = h["v"].split(",").map { |v| h.merge("v" => v) }
      return expanded_entries.map do |e|
        parsed_val, _got_tz = Webhookdb::Replicator::IcalendarEventV1.entry_to_date_or_datetime(e)
        next parsed_val if parsed_val.is_a?(Date)
        # Convert to UTC. We don't work with ActiveSupport timezones in the icalendar code for the most part.
        parsed_val.utc
      end
    end

    def each_feed_event
      bad_event_uids = Set.new
      vevent_lines = []
      in_vevent = false
      while (line = @io.gets)
        begin
          line.rstrip!
        rescue Encoding::CompatibilityError
          # We occassionally get incorrectly encoded files.
          # For example, the response may have a header:
          #   Content-Type: text/calendar; charset=UTF-8
          # but the actual encoding is not:
          #   file -I <filename>
          #   <filename>: text/calendar; charset=iso-8859-1
          # In these cases, there's not much we can do.
          # We can use chardet, but it's a big library and this issue
          # isn't common enough. Instead, try to force the encoding to utf-8,
          # which may break some things, but we'll see what happens.
          line = line.force_encoding("utf-8")
          line = line.scrub
          line = line.rstrip
        end
        if line == "BEGIN:VEVENT"
          in_vevent = true
          vevent_lines << line
        elsif line == "END:VEVENT"
          in_vevent = false
          vevent_lines << line
          h = Webhookdb::Replicator::IcalendarEventV1.vevent_to_hash(vevent_lines)
          vevent_lines.clear
          if h.key?("DTSTART") && h.key?("UID")
            yield h
          else
            bad_event_uids << h.fetch("UID", {}).fetch("v", "[missing]")
          end
        elsif in_vevent
          vevent_lines << line
        end
      end
      return if bad_event_uids.empty?
      @upserter.upserting_replicator.logger.warn("invalid_vevent_hash", vevent_uids: bad_event_uids.sort)
    end
  end
end
