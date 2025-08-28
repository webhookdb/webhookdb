# frozen_string_literal: true

require "webhookdb/procmon"

RSpec.describe Webhookdb::Procmon do
  before(:each) do
    described_class.reset_configuration
    Webhookdb::SHUTTING_DOWN.make_false
    Webhookdb::SHUTTING_DOWN_EVENT.reset
  end

  after(:each) do
    described_class.reset_configuration
  end

  describe "check", :async do
    it "logs disk usage" do
      described_class.mount_path = "/app"
      stat = Sys::Filesystem::Stat.new
      stat.blocks = 1000
      stat.blocks_free = 900
      stat.block_size = 1024
      stat.files = 1000
      stat.files_available = 800
      expect(Sys::Filesystem).to receive(:stat).with("/app").and_return(stat)
      logs = capture_logs_from(described_class.logger, level: :info, formatter: :json) do
        expect do
          described_class.check
        end.to_not publish("webhookdb.developeralert.emitted")
      end
      expect(logs).to have_a_line_matching(/"message":"procmon"/)
      expect(logs).to have_a_line_matching(
        /"disk_used":102400,"disk_perc_used":10,"files_used":200,"files_perc_used":20/,
      )
    end

    it "warns on high disk usage" do
      described_class.mount_path = "/app"
      stat = Sys::Filesystem::Stat.new
      stat.blocks = 1_000_000
      stat.blocks_free = 100_000
      stat.block_size = 4096
      stat.files = 1000
      stat.files_available = 50
      expect(Sys::Filesystem).to receive(:stat).with("/app").and_return(stat).twice
      logs = capture_logs_from(described_class.logger, level: :info, formatter: :json) do
        described_class.check
      end
      expect(logs).to have_a_line_matching(/"message":"procmon"/)
      expect(logs).to have_a_line_matching(
        /"disk_used":3686400000,"disk_perc_used":90,"files_used":950,"files_perc_used":95/,
      )

      expect do
        described_class.check
      end.to publish("webhookdb.developeralert.emitted").with_payload(
        contain_exactly(
          {
            "subsystem" => "Process Monitor (Disk)",
            "emoji" => ":file_folder:",
            "fallback" => "Disk Used: 3.4 GB, Disk % Used: 90%, Files Used: 950, Files % Used: 95%",
            "fields" => [
              {"title" => "Disk Used", "value" => "3.4 GB"},
              {"title" => "Disk % Used", "value" => "90%"},
              {"title" => "Files Used", "value" => 950},
              {"title" => "Files % Used", "value" => "95%"},

            ],
          },
        ),
      )
    end

    it "logs Redis memory usage" do
      expect(Amigo::MemoryPressure.instance).to receive(:get_memory_info).
        and_return({"maxmemory" => "1073741824", "used_memory" => "417452392"})
      logs = capture_logs_from(described_class.logger, level: :info, formatter: :json) do
        expect do
          described_class.check
        end.to_not publish("webhookdb.developeralert.emitted")
      end
      expect(logs).to have_a_line_matching(/"message":"procmon"/)
      expect(logs).to have_a_line_matching(
        /"redis_used_memory":417452392,"redis_memory_pct":39/,
      )
    end

    it "uses total memory if maxmemory is 0" do
      expect(Amigo::MemoryPressure.instance).to receive(:get_memory_info).
        and_return({
                     "maxmemory" => "0",
                     "used_memory" => "973741824",
                     "used_memory_human" => "900MB",
                     "total_system_memory" => "1073741824",
                     "total_system_memory_human" => "1GB",
                     "used_memory_rss_human" => "901MBMB",
                     "used_memory_peak_human" => "902MB",
                   })
      logs = capture_logs_from(described_class.logger, level: :info, formatter: :json) do
        expect do
          described_class.check
        end.to publish("webhookdb.developeralert.emitted")
      end
      expect(logs).to have_a_line_matching(/"message":"procmon"/)
      expect(logs).to have_a_line_matching(
        /"redis_used_memory":973741824,"redis_memory_pct":91/,
      )
    end

    it "warns on high Redis memory usage" do
      expect(Amigo::MemoryPressure.instance).to receive(:get_memory_info).
        and_return({
                     "maxmemory" => "1000000",
                     "maxmemory_human" => "1GB",
                     "used_memory" => "800000",
                     "used_memory_human" => "800MB",
                     "used_memory_rss_human" => "805MB",
                     "used_memory_peak_human" => "810MB",
                   })

      expect do
        described_class.check
      end.to publish("webhookdb.developeralert.emitted").with_payload(
        contain_exactly(
          {
            "subsystem" => "Process Monitor (Redis)",
            "emoji" => ":key:",
            "fallback" => "Used Memory: 800MB, Used Memory RSS: 805MB, Available Memory: 1GB, Peak Memory: 810MB",
            "fields" => [
              {"title" => "Used Memory", "value" => "800MB"},
              {"title" => "Used Memory RSS", "value" => "805MB"},
              {"title" => "Available Memory", "value" => "1GB"},
              {"title" => "Peak Memory", "value" => "810MB"},
            ],
          },
        ),
      )
    end
  end

  it "polls in a thread, and exits when shutting down" do
    described_class.interval = 0
    expect(described_class).to receive(:check).thrice
    expect(Webhookdb::SHUTTING_DOWN).to receive(:true?).and_return(false)
    expect(Webhookdb::SHUTTING_DOWN).to receive(:true?).and_return(false)
    expect(Webhookdb::SHUTTING_DOWN).to receive(:true?).and_return(true)
    t = described_class.run
    expect(t).to be_a(Thread)
    t.join
  end

  it "waits on the shutting down event" do
    described_class.interval = 999
    expect(Webhookdb::SHUTTING_DOWN_EVENT).to receive(:wait).with(999).and_wrap_original do |m, *args|
      Webhookdb::Signals.handle_term
      m.call(*args)
    end
    t = described_class.run
    t.join
  end

  it "raises if the mount path cannot be found" do
    described_class.reset_configuration(mount_path: "/not/found/#{SecureRandom.hex}")
    expect { described_class.run }.to raise_error(/Could not stat on/)
  end
end
