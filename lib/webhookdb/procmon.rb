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
    # At what disk usage percentage should we alert.
    setting :disk_threshold_pct, 70
    # What mount path should we detect disk usage percentage for.
    setting :mount_path, Dir.pwd
    # At what memory usage percentage should we alert.
    # '60' would alert above 600MB used on a 1GB server.
    setting :redis_memory_pct, 60
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
      self.prepare
      checkdisk
      checkredis
      level = @alerted ? self.warn_log_level : self.info_log_level
      self.logger.send(level, "procmon", @logtags)
    end

    def prepare
      @logtags = {}
      @alerted = false
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
      disk_perc_used = ((disk_used / disk_total.to_f) * 100).round
      # disk_perc_free = stat.blocks_free * stat.block_size
      files_used = stat.files - stat.files_available
      files_perc_used = ((files_used / stat.files.to_f) * 100).round
      @logtags.merge!(
        disk_used:,
        disk_perc_used:,
        files_used:,
        files_perc_used:,
      )
      is_alert = disk_perc_used > self.disk_threshold_pct || files_perc_used > self.disk_threshold_pct
      return unless is_alert
      self.devalert(
        "Disk",
        ":file_folder:",
        [
          {title: "Disk Used", value: "#{disk_used.to_f.to_gb.round(1)} GB"},
          {title: "Disk % Used", value: "#{disk_perc_used}%"},
          {title: "Files Used", value: files_used},
          {title: "Files % Used", value: "#{files_perc_used}%"},
        ],
      )
    end

    def checkredis
      meminfo = ::Amigo::MemoryPressure.instance.get_memory_info
      maxmemory = meminfo.fetch("maxmemory").to_i
      avail_mem = maxmemory.zero? ? meminfo.fetch("total_system_memory").to_i : maxmemory
      used_mem = meminfo.fetch("used_memory").to_i
      perc_used_mem = ((used_mem.to_f / avail_mem) * 100).round
      is_alert = perc_used_mem > self.redis_memory_pct
      @logtags[:redis_used_memory] = used_mem
      @logtags[:redis_memory_pct] = perc_used_mem
      return unless is_alert
      avail_mem_human = meminfo.fetch(maxmemory.zero? ? "total_system_memory_human" : "maxmemory_human")
      self.devalert(
        "Redis",
        ":key:",
        [
          {title: "Used Memory", value: meminfo.fetch("used_memory_human")},
          {title: "Used Memory RSS", value: meminfo.fetch("used_memory_rss_human")},
          {title: "Available Memory", value: avail_mem_human},
          {title: "Peak Memory", value: meminfo.fetch("used_memory_peak_human")},
        ],
      )
    end

    private def devalert(subsystem, emoji, fields)
      @alerted = true
      Webhookdb::DeveloperAlert.new(
        subsystem: "Process Monitor (#{subsystem})",
        emoji:,
        fields:,
        fallback: fields.
          map { |f| "#{f[:title]}: #{f[:value]}" }.
          join(", "),
      ).emit
    end
  end
end
