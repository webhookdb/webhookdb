# frozen_string_literal: true

require "tzinfo"
require "tzinfo/data"

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

    SPECIAL_CASE_OFFSETS = {
      "EDT" => -"-0400",
      "EST" => -"-0500",
      "CDT" => -"-0500",
      "CST" => -"-0600",
      "MDT" => -"-0600",
      "MST" => -"-0700",
      "PDT" => -"-0700",
      "PST" => -"-0800",
      "Microsoft/Utc" => -"+00",
      "(UTC) Coordinated Universal Time" => -"+00",
    }.freeze

    EASTERN = -"America/New_York"
    CENTRAL = -"America/Chicago"
    MOUNTAIN = -"America/Denver"
    PACIFIC = -"America/Los_Angeles"

    SPECIAL_CASE_LINKS = {
      "HT_ESTL" => EASTERN,
      "HT_CSTL" => CENTRAL,
      "HT_MSTL" => MOUNTAIN,
      "HT_PSTL" => PACIFIC,

      "HT_EST" => EASTERN,
      "HT_CST" => CENTRAL,
      "HT_MST" => MOUNTAIN,
      "HT_PST" => PACIFIC,

      "Yukon Standard Time" => "America/Whitehorse",

      "Eastern Standard Time" => EASTERN,
      "Eastern Time" => EASTERN,
      "Central Standard Time" => CENTRAL,
      "Central Time" => CENTRAL,
      "Mountain Standard Time" => MOUNTAIN,
      "Mountain Time" => MOUNTAIN,
      "Pacific Standard Time" => PACIFIC,
      "Pacific Time" => PACIFIC,

      "GMT -0500 (Standard) / GMT -0400 (Daylight)" => EASTERN,
      "GMT -0600 (Standard) / GMT -0500 (Daylight)" => CENTRAL,
      "GMT -0700 (Standard) / GMT -0600 (Daylight)" => MOUNTAIN,
      "GMT -0800 (Standard) / GMT -0700 (Daylight)" => PACIFIC,
    }.freeze

    UUID_RE = /\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/i

    CANONICAL_MAPPING = TZInfo::Timezone.all_identifiers.to_h { |d| [d.tr("-", "_").upcase, d] }

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
      tzid = tzid.delete_prefix("/").delete_prefix("Etc/").delete_prefix("tzone://")
      # Order these conditions based on how common they are, and how expensive the check is.
      if (zone = Time.find_zone(tzid))
        # Happy path, the zone exists.
        return [zone.parse(value), true]
      end
      if (new_tzid = SPECIAL_CASE_LINKS[tzid])
        # This is a weird zone we need to explicitly point to a new one.
        return parse_time_with_tzid(value, new_tzid)
      end
      if (zone = self.windows_name_to_tz[tzid])
        # Windows has their own zones, of course.
        return [zone.parse(value), true]
      end
      if (offset = SPECIAL_CASE_OFFSETS[tzid])
        # Some timezones need explicit offsets, rather than handling them as timezones (EST and EDT, for example).
        return [Time.parse(value + offset), true]
      end
      if (md = /^\(?(GMT|UTC)([+-]\d\d?:?\d?\d?)/.match(tzid))
        # Offsets with and without names: (UTC-07:00) Arizona, GMT+01
        offset = md[2]
        if offset.size == 2
          # values like Etc/GMT-2 into -0200
          offset = "#{offset[0]}0#{offset[1]}:00"
        end
        return [Time.parse(value + offset), true]
      end
      if (zone = Time.find_zone(tzid.tr("-", "/")))
        # Turn 'US-Pacific' into 'US/Pacific'
        return [zone.parse(value), true]
      end
      if (canonical = CANONICAL_MAPPING[tzid.tr("-", "_").upcase])
        # Incorrect casing means we should retry with a canonical zone.
        return parse_time_with_tzid(value, canonical)
      end
      if /[A-Za-z]{2}\d\d\d\d$/.match?(tzid)
        # Weird stuff like 'Eastern Standard Time2025', due to a malformed icalendar
        return parse_time_with_tzid(value, tzid[...-4])
      end
      if (pair = SPECIAL_CASE_LINKS.find { |k, _v| tzid.start_with?(k) })
        return parse_time_with_tzid(value, pair[1])
      end
      # At this point, we know we can't parse, so will be using UTC.
      # The question is if we alert or not.
      is_custom = tzid =~ /no TZ description/i ||
        tzid =~ /Custom/i || # Microsoft/Custom, UnnamedCustomTimeZone, Customized Time Zone 2
        tzid =~ /^d+$/ || # '1'
        tzid =~ UUID_RE
      is_ignored = self.nonsense_tzids&.include?(tzid.upcase)
      do_alert = !is_custom && !is_ignored

      if do_alert
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
      utc = Time.find_zone!("UTC")
      return [utc.parse(value), false]
    end
  end
end
