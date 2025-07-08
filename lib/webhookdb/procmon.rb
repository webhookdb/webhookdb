# frozen_string_literal: true

require "appydays/configurable"
require "appydays/loggable"
require "sys/filesystem"

require "webhookdb/signals"

# Basic monitor for things like disk space, in environments that don't have other monitors for it,
# like Render or Heroku.
class Webhookdb::Procmon
  include Appydays::Configurable
  include Appydays::Loggable

  configurable(:procmon) do
    setting :enabled, true
    setting :interval, 60
    # At what disk usage percentage should be alert.
    setting :disk_threshold_pct, 70
    # What mount path should we detect disk usage percentage for.
    setting :mount_path, Dir.pwd
    setting :info_log_level, :info
    setting :warn_log_level, :warn
  end

  class << self
    def run
      check
      t = Thread.new do
        loop do
          break if Webhookdb::SHUTTING_DOWN.true?
          Webhookdb::SHUTTING_DOWN_EVENT.wait(self.interval)
          check
        end
      end
      return t
    end

    def check
      checkdisk
    end

    def checkdisk
      begin
        stat = Sys::Filesystem.stat(self.mount_path)
      rescue Sys::Filesystem::Error => e
        msg = "Could not stat on #{self.mount_path}. Change PROCMON_MOUNT_PATH, " \
              "or set PROCMON_ENABLED=false. Error: #{e}"
        raise msg.to_s
      end
      blocks_used = stat.blocks - stat.blocks_free
      disk_used = blocks_used * stat.block_size
      # disk_free = stat.blocks_free - stat.block_size
      disk_total = stat.blocks * stat.block_size
      disk_perc_used = ((disk_used / disk_total.to_f) * 100).to_i
      # disk_perc_free = stat.blocks_free * stat.block_size
      files_used = stat.files - stat.files_available
      files_perc_used = ((files_used / stat.files.to_f) * 100).to_i
      is_alert = disk_perc_used > self.disk_threshold_pct || files_perc_used > self.disk_threshold_pct
      if is_alert
        fields = [
          {title: "Disk Used", value: "#{disk_used.to_f.to_gb.round(1)} GB"},
          {title: "Disk % Used", value: "#{disk_perc_used}%"},
          {title: "Files Used", value: files_used},
          {title: "Files % Used", value: "#{files_perc_used}%"},
        ]
        Webhookdb::DeveloperAlert.new(
          subsystem: "Process Monitor",
          emoji: ":file_folder:",
          fallback: fields.
            map { |f| "#{f[:title]}: #{f[:value]}" }.
            join(", "),
          fields:,
        ).emit
      end
      level = is_alert ? self.warn_log_level : self.info_log_level
      self.logger.send(level, "procmon",
                       disk_used:,
                       disk_perc_used:,
                       files_used:,
                       files_perc_used:,)
    end
  end
end
