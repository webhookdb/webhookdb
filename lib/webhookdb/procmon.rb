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
    # Alert about jobs which have been running for longer than this number of seconds (default 2 hours).
    setting :long_running_jobs_age, 2.hours.to_i
    # Only alert when there are more than this many long-running jobs.
    # It is hard to avoid *all* long-running jobs, and the occassional long job can be managed through metrics.
    # But we want to alert if we end up becoming saturated with long-running jobs.
    # By default, alert if we have more than one sidekiq worker worth of long-running jobs.
    setting :long_running_jobs_count, ENV.fetch("SIDEKIQ_CONCURRENCY", "5").to_i

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
      checksidekiq
      level = @alerted ? self.warn_log_level : self.info_log_level
      self.logger.send(level, "procmon", @logtags)
    end

    def prepare
      @now = Time.now
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
          {title: "Files Used", value: files_used.to_s},
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

    def checksidekiq
      all_work_count = 0
      slow_work = []
      self.sidekiq_work do |work|
        all_work_count += 1
        age = @now - work.run_at
        slow_work << work if age > self.long_running_jobs_age
        # next if work.run_at > old_job_threshold
        # labels << "#{work.job.klass}(#{work.job.jid})"
      end
      @logtags[:sidekiq_running_jobs] = all_work_count
      @logtags[:sidekiq_slow_jobs] = slow_work.count
      return if slow_work.count <= self.long_running_jobs_count
      slow_work.sort_by!(&:run_at)
      slow_work = slow_work.take(6)
      self.devalert(
        "Sidekiq",
        ":ice_hockey_stick_and_puck:",
        [
          {title: "Running Jobs", value: all_work_count.to_s},
          {title: "Slow Jobs", value: slow_work.count.to_s},
        ].concat(slow_work.sort_by(&:run_at).take(6).map do |w|
          age = ActiveSupport::Duration.build((@now - w.run_at).round).inspect
          {title: w.job.jid, value: "`#{w.job.klass}` / #{age}", short: false}
        end),
      )
    end

    def sidekiq_work(&)
      Sidekiq::WorkSet.new.each do |_wid, _tid, work|
        yield(work)
      end
    end

    private def devalert(subsystem, emoji, fields)
      @alerted = true
      fields.each do |f|
        f[:short] = true unless f.key?(:short)
      end
      Webhookdb::DeveloperAlert.new(
        subsystem: "Process Monitor (#{subsystem})",
        emoji:,
        fields:,
        fallback: fields.
          map { |f| "#{f[:title]}: #{f[:value].delete('`')}" }.
          join(", "),
      ).emit
    end
  end
end
