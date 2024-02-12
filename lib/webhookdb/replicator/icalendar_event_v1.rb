# frozen_string_literal: true

require "webhookdb/icalendar"
require "webhookdb/windows_tz"

class Webhookdb::Replicator::IcalendarEventV1 < Webhookdb::Replicator::Base
  include Appydays::Loggable

  def documentation_url = Webhookdb::Icalendar::DOCUMENTATION_URL

  # @return [Webhookdb::Replicator::Descriptor]
  def self.descriptor
    return Webhookdb::Replicator::Descriptor.new(
      name: "icalendar_event_v1",
      ctor: ->(sint) { Webhookdb::Replicator::IcalendarEventV1.new(sint) },
      dependency_descriptor: Webhookdb::Replicator::IcalendarCalendarV1.descriptor,
      feature_roles: [],
      resource_name_singular: "iCalendar Event",
      supports_webhooks: true,
      description: "Individual events in an icalendar. See icalendar_calendar_v1.",
      api_docs_url: "https://icalendar.org/",
    )
  end

  CONV_REMOTE_KEY = Webhookdb::Replicator::Column::IsomorphicProc.new(
    ruby: lambda do |_, resource:, **_|
      "#{resource.fetch('calendar_external_id')}-#{resource.fetch('UID').fetch('v')}"
    end,
    # Because this is a non-nullable key, we never need this in SQL
    sql: ->(_) { Sequel.lit("'do not use'") },
  )

  # Return tuple of parsed date or datetime, and a boolean of whether
  # the timezone could be parsed (true if date was parsed).
  # @return [Array<Time,Date,true,false,nil>]
  def self.entry_to_date_or_datetime(entry)
    return [self.entry_to_date(entry), true] if self.value_is_date_str?(entry.fetch("v"))
    return self.entry_to_datetime(entry)
  end

  def self.entry_is_date_str?(e) = self.value_is_date_str?(e.fetch("v"))
  def self.value_is_date_str?(v) = v.length === 8

  # Return tuple of parsed datetime, and a boolean of whether
  # the timezone could be parsed.
  # @return [Array<Time,true,false,nil>]
  def self.entry_to_datetime(entry)
    value = entry.fetch("v")
    raise ArgumentError, "do not pass a date string" if self.value_is_date_str?(value)
    return [Time.strptime(value, "%Y%m%dT%H%M%S%Z"), true] if value.end_with?("Z")
    if (tzid = entry["TZID"])
      return self._parse_time_with_tzid(value, tzid)
    end
    return [Time.find_zone!("UTC").parse(value), false]
  end

  # @return [Date,nil]
  def self.entry_to_date(entry)
    value = entry.fetch("v")
    raise ArgumentError, "must pass a date string" unless self.value_is_date_str?(value)
    return Date.strptime(value, "%Y%m%d")
  end

  CONV_DATE = Webhookdb::Replicator::Column::IsomorphicProc.new(
    ruby: lambda do |entry, **|
      self.entry_to_date(entry) if entry.is_a?(Hash) && self.entry_is_date_str?(entry)
    end,
    sql: Webhookdb::Replicator::Column::NOT_IMPLEMENTED,
  )
  CONV_DATETIME = Webhookdb::Replicator::Column::IsomorphicProc.new(
    ruby: lambda do |entry, **|
      if entry.is_a?(Hash)
        if self.entry_is_date_str?(entry)
          nil
        else
          self.entry_to_datetime(entry).first
        end
      else
        # Entry may be a time if this was from the defaulter
        entry
      end
    end,
    sql: ->(_) { raise NotImplementedError },
  )
  CONV_MISSING_TZ = Webhookdb::Replicator::Column::IsomorphicProc.new(
    ruby: lambda do |entry, **|
      may_have_missing_tz = entry.is_a?(Hash) && !self.entry_is_date_str?(entry)
      if may_have_missing_tz
        tzparsed = self.entry_to_datetime(entry)[1]
        !tzparsed
      else
        false
      end
    end,
    sql: ->(_) { Sequel[false] },
  )
  CONV_GEO_LAT = Webhookdb::Replicator::Column.converter_array_element(index: 0, sep: ";", cls: DECIMAL)
  CONV_GEO_LNG = Webhookdb::Replicator::Column.converter_array_element(index: 1, sep: ";", cls: DECIMAL)
  CONV_COMMA_SEP_ARRAY = Webhookdb::Replicator::Column::IsomorphicProc.new(
    ruby: lambda do |entry, **|
      next [] if entry.nil?
      entries = []
      entry.each do |e|
        entries.concat(e.fetch("v").split(",").map(&:strip))
      end
      entries
    end,
    sql: ->(_) { raise NotImplementedError },
  )

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
    tsconv = {converter: CONV_DATETIME}
    dateconv = {converter: CONV_DATE}
    return [
      col.new(:calendar_external_id, TEXT, index: true),
      col.new(:uid, TEXT, data_key: ["UID", "v"], index: true),
      col.new(:row_updated_at, TIMESTAMP, index: true, defaulter: :now, optional: true),
      col.new(:last_modified_at,
              TIMESTAMP,
              index: true,
              data_key: "LAST-MODIFIED",
              defaulter: :now,
              optional: true,
              **tsconv,),
      col.new(:created_at, TIMESTAMP, optional: true, data_key: "CREATED", **tsconv),
      col.new(:start_at, TIMESTAMP, index: true, index_not_null: true, data_key: "DTSTART", **tsconv),
      # This is True when start/end at fields are missing timezones in the underlying feed.
      # Their timestamps are in UTC.
      col.new(:missing_timezone, BOOLEAN, data_key: "DTSTART", converter: CONV_MISSING_TZ),
      col.new(:end_at, TIMESTAMP, index: true, index_not_null: true, data_key: "DTEND", optional: true, **tsconv),
      col.new(:start_date, DATE, index: true, index_not_null: true, data_key: "DTSTART", **dateconv),
      col.new(:end_date, DATE, index: true, index_not_null: true, data_key: "DTEND", optional: true, **dateconv),
      col.new(:status, TEXT, data_key: ["STATUS", "v"], optional: true),
      col.new(:categories, TEXT_ARRAY, data_key: ["CATEGORIES"], optional: true, converter: CONV_COMMA_SEP_ARRAY),
      col.new(:priority, INTEGER, data_key: ["PRIORITY", "v"], optional: true, converter: col::CONV_TO_I),
      col.new(:geo_lat, DECIMAL, data_key: ["GEO", "v"], optional: true, converter: CONV_GEO_LAT),
      col.new(:geo_lng, DECIMAL, data_key: ["GEO", "v"], optional: true, converter: CONV_GEO_LNG),
      col.new(:classification, TEXT, data_key: ["CLASS", "v"], optional: true),
      col.new(:recurring_event_id, TEXT, optional: true, index: true, index_not_null: true),
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

  def _prepare_for_insert(resource, event, request, enrichment)
    h = super
    # Events can have a DTSTART, but no DTEND.
    # https://icalendar.org/iCalendar-RFC-5545/3-6-1-event-component.html
    # In these cases, we need to:
    # - Use the duration, given.
    # - Dates default to the next day.
    # - Times default to start time.
    if (_implicit_end_time = h[:start_at] && !h[:end_at])
      self._set_implicit_end_at(resource, h)
    elsif (_implicit_end_date = h[:start_date] && !h[:end_date])
      self._set_implicit_end_date(resource, h)
    end
    return h
  end

  def _set_implicit_end_date(resource, h)
    if (d = resource["DURATION"])
      # See https://icalendar.org/iCalendar-RFC-5545/3-3-6-duration.html
      dur = ActiveSupport::Duration.parse(d.fetch("v"))
      h[:end_date] = h[:start_date] + dur
      return
    end
    h[:end_date] = h[:start_date] + 1.day
  end

  def _set_implicit_end_at(resource, h)
    if (d = resource["DURATION"])
      dur = ActiveSupport::Duration.parse(d.fetch("v"))
      h[:end_at] = h[:start_at] + dur
      return
    end
    h[:end_at] = h[:start_at]
  end

  # @return [Array<Webhookdb::Replicator::IndexSpec>]
  def _extra_index_specs
    return [
      Webhookdb::Replicator::IndexSpec.new(
        columns: [:calendar_external_id, :start_at, :end_at],
        where: Sequel[:status].is_distinct_from("CANCELLED") & (Sequel[:start_at] !~ nil),
      ),
      Webhookdb::Replicator::IndexSpec.new(
        columns: [:calendar_external_id, :start_date, :end_date],
        where: Sequel[:status].is_distinct_from("CANCELLED") & (Sequel[:start_date] !~ nil),
      ),
    ]
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

  # https://datatracker.ietf.org/doc/html/rfc5545#section-3.6.1
  # The following are OPTIONAL, and MAY occur more than once.
  ARRAY_KEYS = [
    "ATTACH",
    "ATTENDEE",
    "CATEGORIES",
    "COMMENT",
    "CONTACT",
    "EXDATE",
    "RSTATUS",
    "RELATED",
    "RESOURCES",
    "RDATE",
    "X-PROP",
    "IANA-PROP",
  ].freeze

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
  #
  # If the zone cannot be parsed, assume UTC.
  #
  # Return a tuple of [Time, true if the zone could be parsed].
  # If the zone cannot be parsed, you usually want to log or store it.
  def self._parse_time_with_tzid(value, tzid)
    if (zone = Time.find_zone(tzid.tr("-", "/")))
      return [zone.parse(value), true]
    end
    if /^(GMT|UTC)[+-]\d\d\d\d$/.match?(tzid)
      offset = tzid[3..]
      return [Time.parse(value + offset), true]
    end
    if (zone = Webhookdb::WindowsTZ.windows_name_to_tz[tzid])
      return [zone.parse(value), true]
    end
    zone = Time.find_zone!("UTC")
    return [zone.parse(value), false]
  end

  def on_dependency_webhook_upsert(_ical_svc, _ical_row, **)
    # We use an async job to sync when the dependency syncs
    return
  end

  def calculate_webhook_state_machine
    if (step = self.calculate_dependency_state_machine_step(dependency_help: ""))
      return step
    end
    step = Webhookdb::Replicator::StateMachineStep.new
    step.output = %(Great! You are all set.
Refer to https://docs.webhookdb.com/guides/icalendar/ for detailed instructions
on syncing data from iCalendar/ics feeds.

#{self._query_help_output(prefix: "Once data is available, you can query #{self.resource_name_plural}")})
    return step.completed
  end

  def backfill_not_supported_message
    return %(#{self.resource_name_singular} does not support backfilling.
See https://docs.webhookdb.com/guides/icalendar/ for instructions on setting up your integration.

You can POST 'SYNC' messages to WebhookDB to force-sync a user's feed,
though keep in mind calendar providers only refresh feeds periodically.)
  end
end
