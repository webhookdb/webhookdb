# frozen_string_literal: true

# Map Windows Timezone names to IANA names (and ActiveSupport timezones).
# Outlook calendar uses these timezones.
module Webhookdb::WindowsTZ
  class << self
    attr_accessor :_win_to_tz

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
  end
end
