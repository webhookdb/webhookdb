# frozen_string_literal: true

module Webhookdb::Timezone
  include Appydays::Configurable

  configurable(:timezone) do
    # Timezones that are nonsense and do not want to warn about.
    # Match is case-insensitive.
    setting :nonsense_tzids, ""

    after_configured do
      self.nonsense_tzids = self.nonsense_tzids&.upcase
    end
  end

  class << self
    attr_accessor :_win_to_tz

    # Map Windows Timezone names to IANA names (and ActiveSupport timezones).
    # Outlook calendar uses these timezones.
    # @return [Hash<String => ActiveSupport::TimeZone>]
    def windows_name_to_tz
      return self._win_to_tz if self._win_to_tz
      win_to_tz = {}
      self._win_to_tz = win_to_tz

      all_win_names = Set.new
      File.open(Webhookdb::DATA_DIR + "windows_tz.txt").each do |line|
        line.strip!
        next if line.blank? || line.start_with?("#")
        iana, win = line.split(/\s/, 2)
        next if win_to_tz.include?(win)
        all_win_names.add(win)
        tz = ActiveSupport::TimeZone[iana]
        next if tz.nil?
        win_to_tz[win] = tz
      end
      win_to_tz.each_key { |k| all_win_names.delete(k) }
      raise Webhookdb::InvariantViolation, "unmapped windows timezones: #{all_win_names.join(', ')}" unless
        all_win_names.empty?
      return win_to_tz
    end

    # Given a tzid and value for a timestamp, return a Time (with a timezone).
    # While there's no formal naming scheme, we see the following forms:
    #
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
    # Return a tuple of [Time, true] if the tzid refers to a valid zone,
    # or [Time, false] if tzid is not valid.
    #
    # Invalid zones happen for one of two reasons:
    # - It is truly a nonsense zone ID. In that case, add this zone to TIMEZONE_NONSENSE_TZIDS.
    # - It is not in our timzone database. In that case, update the tzinfo-data gem.
    # We use the tzinfo-data gem so we don't depend on the system timezone,
    # but this means we need to keep it updated manually.
    def parse_time_with_tzid(value, tzid)
      if (zone = Time.find_zone(tzid.tr("-", "/")))
        return [zone.parse(value), true]
      end
      if /^(GMT|UTC)[+-]\d\d\d?\d?$/.match?(tzid)
        offset = tzid[3..]
        return [Time.parse(value + offset), true]
      end
      if (zone = self.windows_name_to_tz[tzid])
        return [zone.parse(value), true]
      end
      unless self.nonsense_tzids&.include?(tzid.upcase)
        # We only want to alert weekly, and it's okay to alert globally,
        # since responding is a system administrator responsibility (update config or gem).
        # Have a fast path to ensure we don't hit the DB in this code as it may be called a lot.
        cachekey = "invalidtz-#{tzid}"
        Webhookdb.cached_get(cachekey) do
          Webhookdb::Idempotency.every(1.week).transaction_ok.under_key(cachekey) do
            Webhookdb::DeveloperAlert.new(
              subsystem: "Timezone Database",
              emoji: ":world_map:",
              fallback: "Invalid TZID: #{tzid}. Update tzinfo-data gem, or add this to TIMEZONE_NONSENSE_TZIDS.",
              fields: [
                {title: "Timezone ID", value: tzid, short: true},
                {title: "Time string", value: value, short: true},
                {title: "Action", value: "Update tzinfo-data gem, or add this ID to TIMEZONE_NONSENSE_TZIDS config."},
              ],
            ).emit
          end
        end
      end
      zone = Time.find_zone!("UTC")
      return [zone.parse(value), false]
    end
  end
end
