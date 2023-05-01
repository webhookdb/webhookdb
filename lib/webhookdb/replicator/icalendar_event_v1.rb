# frozen_string_literal: true

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

  CONV_DATE = Webhookdb::Replicator::Column::IsomorphicProc.new(
    ruby: lambda do |entry, **|
      break nil if entry.nil?
      value = entry.fetch("v")
      value.length == 8 ? Date.strptime(value, "%Y%m%d") : nil
    end,
    sql: ->(_) { raise NotImplementedError },
  )
  CONV_DATETIME = Webhookdb::Replicator::Column::IsomorphicProc.new(
    ruby: lambda do |entry, **|
      break entry if entry.nil? || entry.is_a?(Time) # If the default was used or there's no value
      value = entry.fetch("v")
      if value.end_with?("Z")
        Time.strptime(value, "%Y%m%dT%H%M%S%Z")
      elsif value.length == 8
        nil
      elsif (tzid = entry["TZID"])
        # While there's no formal naming scheme, we only really see normal forms like 'America/Los_Angeles'
        # or with different chars (like in the docs), 'US-Eastern'.
        # In theory this can be any value, and must be given in the calendar feed (VTIMEZONE).
        # We can solve for that if needed.
        zone = Time.find_zone(tzid.tr("-", "/"))
        zone.parse(value)
      end
    end,
    sql: ->(_) { raise NotImplementedError },
  )
  CONV_GEO_LAT = Webhookdb::Replicator::Column::IsomorphicProc.new(
    ruby: lambda do |value, **|
      break nil if value.nil?
      BigDecimal(value.split(";")[0])
    end,
    sql: ->(_) { raise NotImplementedError },
  )
  CONV_GEO_LNG = Webhookdb::Replicator::Column::IsomorphicProc.new(
    ruby: lambda do |value, **|
      break nil if value.nil?
      BigDecimal(value.split(";")[1])
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
    ]
  end

  def _resource_and_event(request)
    return request.body, nil
  end

  def _resource_to_data(r, *)
    data = r.dup
    data.delete("calendar_external_id")
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
      full_key, value = line.split(":", 2)
      key_parts = full_key.split(";")
      keyname = key_parts.shift
      value.gsub!("\\r\\n", "\r\n")
      value.gsub!("\\n", "\n")
      value.gsub!("\\t", "\t")
      entry = {"v" => value}
      key_parts.each do |keypart|
        keypart_name, keypart_val = keypart.split("=", 2)
        entry[keypart_name] = keypart_val
      end
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
