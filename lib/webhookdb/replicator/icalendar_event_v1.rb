# frozen_string_literal: true

require "webhookdb/windows_tz"

class Webhookdb::Replicator::IcalendarEventV1 < Webhookdb::Replicator::Base
  include Appydays::Loggable

  # @return [Webhookdb::Replicator::Descriptor]
  def self.descriptor
    return Webhookdb::Replicator::Descriptor.new(
      name: "icalendar_event_v1",
      ctor: ->(sint) { Webhookdb::Replicator::IcalendarEventV1.new(sint) },
      dependency_descriptor: Webhookdb::Replicator::IcalendarCalendarV1.descriptor,
      feature_roles: ["beta"],
      resource_name_singular: "iCalendar Event",
    )
  end

  CONV_REMOTE_KEY = Webhookdb::Replicator::Column::IsomorphicProc.new(
    ruby: lambda do |_, resource:, **_|
      "#{resource.fetch('calendar_external_id')}-#{resource.fetch('UID').fetch('v')}"
    end,
    # Because this is a non-nullable key, we never need this in SQL
    sql: ->(_) { Sequel.lit("'do not use'") },
  )

  def self.value_is_date_str?(v)
    return v.length === 8
  end

  # @return [Time,nil]
  def self.entry_to_datetime(entry)
    return entry if entry.nil? || entry.is_a?(Time) # If the default was used or there's no value
    value = entry.fetch("v")
    return Time.strptime(value, "%Y%m%dT%H%M%S%Z") if value.end_with?("Z")
    return nil if self.value_is_date_str?(value)
    tzid = entry["TZID"]
    return self._parse_time_with_tzid(value, tzid) if tzid
    raise ArgumentError, "cannot convert #{entry} to datetime"
  end

  # @return [Date,nil]
  def self.entry_to_date(entry)
    return nil if entry.nil?
    value = entry.fetch("v")
    return nil unless self.value_is_date_str?(value)
    return Date.strptime(value, "%Y%m%d")
  end

  CONV_DATE = Webhookdb::Replicator::Column::IsomorphicProc.new(
    ruby: lambda do |entry, **|
      self.entry_to_date(entry)
    end,
    sql: ->(_) { raise NotImplementedError },
  )
  CONV_DATETIME = Webhookdb::Replicator::Column::IsomorphicProc.new(
    ruby: lambda do |entry, **|
      self.entry_to_datetime(entry)
    end,
    sql: ->(_) { raise NotImplementedError },
  )
  CONV_GEO_LAT = Webhookdb::Replicator::Column.converter_array_element(index: 0, sep: ";", cls: DECIMAL)
  CONV_GEO_LNG = Webhookdb::Replicator::Column.converter_array_element(index: 1, sep: ";", cls: DECIMAL)

  def _remote_key_column
    return Webhookdb::Replicator::Column.new(
      :compound_identity,
      TEXT,
      data_key: "<compound key, see converter>",
      index: true,
      converter: CONV_REMOTE_KEY,
      optional: true, # This is done via the converter, data_key never exists
    )
  end

  def _denormalized_columns
    col = Webhookdb::Replicator::Column
    tsopts = {converter: CONV_DATETIME}
    dateopts = {converter: CONV_DATE}
    return [
      col.new(:calendar_external_id, TEXT, index: true),
      col.new(:uid, TEXT, data_key: ["UID", "v"], index: true),
      col.new(:row_updated_at, TIMESTAMP, index: true, defaulter: :now, optional: true),
      col.new(:last_modified_at, TIMESTAMP, index: true, data_key: "LAST-MODIFIED",
                                            defaulter: :now, optional: true, **tsopts,),
      col.new(:created_at, TIMESTAMP, optional: true, data_key: "CREATED", **tsopts),
      col.new(:start_at, TIMESTAMP, index: true, data_key: "DTSTART", **tsopts),
      col.new(:end_at, TIMESTAMP, index: true, data_key: "DTEND", optional: true, **tsopts),
      col.new(:start_date, DATE, index: true, data_key: "DTSTART", **dateopts),
      col.new(:end_date, DATE, index: true, data_key: "DTEND", optional: true, **dateopts),
      col.new(:status, TEXT, data_key: ["STATUS", "v"], optional: true),
      col.new(:categories, TEXT_ARRAY, data_key: ["CATEGORIES", "v"],
                                       optional: true, converter: col::CONV_COMMA_SEP,),
      col.new(:priority, INTEGER, data_key: ["PRIORITY", "v"], optional: true, converter: col::CONV_TO_I),
      col.new(:geo_lat, DECIMAL, data_key: ["GEO", "v"], optional: true, converter: CONV_GEO_LAT),
      col.new(:geo_lng, DECIMAL, data_key: ["GEO", "v"], optional: true, converter: CONV_GEO_LNG),
      col.new(:classification, TEXT, data_key: ["CLASS", "v"], optional: true),
      col.new(:recurring_event_id, TEXT, optional: true, index: true),
      col.new(:recurring_event_sequence, INTEGER, optional: true),
    ]
  end

  def _resource_and_event(request)
    return request.body, nil
  end

  def _resource_to_data(r, *)
    data = r.dup
    data.delete("calendar_external_id")
    data.delete("recurring_event_id")
    data.delete("recurring_event_sequence")
    return data
  end

  def _update_where_expr
    return self.qualified_table_sequel_identifier[:last_modified_at] < Sequel[:excluded][:last_modified_at]
  end

  # @param [Array<String>] lines
  # @return [String]
  def self._compact_vevent_lines(lines)
    # Walk backwards from the end, joining continuation lines.
    # Very hard to reason about this if it's written using normal array stuff.
    (1..(lines.length - 1)).reverse_each do |idx|
      line = lines[idx]
      prevline = lines[idx - 1]
      next unless line.start_with?(/\s+/)
      line.lstrip!
      prevline << line
      lines.delete_at(idx)
    end
    s = lines.join("\n")
    return s
  end

  def self.vevent_to_hash(vevent_lines)
    result = {}
    vevent_str = self._compact_vevent_lines(vevent_lines)
    nest_depth = 0
    vevent_str.lines.each do |line|
      if line.start_with?("BEGIN")
        nest_depth += 1
        next
      elsif line.start_with?("END")
        nest_depth -= 1
        next
      end
      next if nest_depth > 1
      line.strip!
      next if line.empty?
      keyname, value, params = self._parse_line(line)
      unless value.nil?
        value.gsub!("\\r\\n", "\r\n")
        value.gsub!("\\n", "\n")
        value.gsub!("\\t", "\t")
      end
      entry = {"v" => value}
      entry.merge!(params)
      if ARRAY_KEYS.include?(keyname)
        result[keyname] ||= []
        result[keyname] << entry
      else
        result[keyname] = entry
      end
    end
    return result
  end

  ARRAY_KEYS = ["ATTENDEE"].freeze

  NAME = "[-a-zA-Z0-9]+"
  QSTR = '"[^"]*"'
  PTEXT = '[^";:,]*'
  PVALUE = "(?:#{QSTR}|#{PTEXT})".freeze
  PARAM = "(#{NAME})=(#{PVALUE}(?:,#{PVALUE})*)".freeze
  VALUE = ".*"
  LINE = "(?<name>#{NAME})(?<params>(?:;#{PARAM})*):(?<value>#{VALUE})".freeze

  # @param input [String]
  def self._parse_line(input)
    parts = /#{LINE}/o.match(input)
    return input, nil, {} if parts.nil?
    params = {}
    parts[:params].scan(/#{PARAM}/o) do |match|
      param_name = match[0]
      # params[param_name] ||= []
      match[1].scan(/#{PVALUE}/o) do |param_value|
        if param_value.size.positive?
          param_value = param_value.gsub(/\A"|"\z/, "")
          params[param_name] = param_value
          # params["x-tz-info"] = timezone_store.retrieve param_value if param_name == "tzid"
        end
      end
    end
    return parts[:name], parts[:value], params
  end

  # Given a tzid and value for a timestamp, return a Time (with a timezone).
  # While there's no formal naming scheme, we see the following forms:
  # - valid names like America/Los_Angeles, US/Eastern
  # - dashes, like America-Los_Angeles, US-Eastern
  # - Offsets, like GMT-0700'
  #
  # In theory this can be any value, and must be given in the calendar feed (VTIMEZONE).
  # However that is extremely difficult; even the icalendar gem doesn't seem to do it 100% right.
  # We can solve for this if needed; in the meantime, log it in Sentry and use UTC.
  def self._parse_time_with_tzid(value, tzid)
    if (zone = Time.find_zone(tzid.tr("-", "/")))
      return zone.parse(value)
    end
    if /^(GMT|UTC)[+-]\d\d\d\d$/.match?(tzid)
      offset = tzid[3..]
      return Time.parse(value + offset)
    end
    if (zone = Webhookdb::WindowsTZ.windows_name_to_tz[tzid])
      return zone.parse(value)
    end
    Sentry.with_scope do |scope|
      scope.set_extras(timezone_id: tzid, time_value: value)
      Sentry.capture_message("Unhandled iCalendar timezone")
    end
    zone = Time.find_zone!("UTC")
    return zone.parse(value)
  end

  def on_dependency_webhook_upsert(_ical_svc, _ical_row, **)
    # We use an async job to sync when the dependency syncs
    return
  end

  def calculate_create_state_machine
    if (step = self.calculate_dependency_state_machine_step(dependency_help: ""))
      return step
    end
    step = Webhookdb::Replicator::StateMachineStep.new
    step.output = %(Great! You are all set.
Refer to https://webhookdb.com/docs/icalendar for detailed instructions
on syncing data from iCalendar/ics feeds.

#{self._query_help_output(prefix: "Once data is available, you can query #{self.resource_name_plural}")})
    return step.completed
  end

  def calculate_backfill_state_machine
    step = Webhookdb::Replicator::StateMachineStep.new
    step.output = %(#{self.resource_name_singular} does not support backfilling.
See https://webhookdb.com/docs/icalendar for instructions on setting up your integration.
You can send WebhookDB the 'SYNC' messages to force-sync a user's feed,
though keep in mind calendar providers only refresh feeds periodically.

#{self._query_help_output(prefix: "You can query available #{self.resource_name_plural}")})
    step.error_code = "icalendar_no_backfill"
    return step.completed
  end
end
