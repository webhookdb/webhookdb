# frozen_string_literal: true

require "webhookdb/procmon"

RSpec.describe Webhookdb::Procmon do
  before(:each) do
    described_class.reset_configuration(singleton_hostname_regex: /.*/)
    ENV["DYNO"] = "web1"
    # We don't know the memory usage of the system we're running on, so never cause a false positive during tests.
    allow(Sys::Memory).to receive(:load).and_return(1)
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
            "emoji" => ":dvd:",
            "fallback" => "Host: web1, Disk Used: 3.4 GB, Disk % Used: 90%, Files Used: 950, Files % Used: 95%",
            "fields" => [
              {"title" => "Host", "value" => "web1", "short" => true},
              {"title" => "Disk Used", "value" => "3.4 GB", "short" => true},
              {"title" => "Disk % Used", "value" => "90%", "short" => true},
              {"title" => "Files Used", "value" => "950", "short" => true},
              {"title" => "Files % Used", "value" => "95%", "short" => true},

            ],
          },
        ),
      )
    end

    it "logs memory usage" do
      expect(Sys::Memory).to receive(:used).and_return(123_456_789)
      expect(Sys::Memory).to receive(:load).and_return(45)
      logs = capture_logs_from(described_class.logger, level: :info, formatter: :json) do
        expect do
          described_class.check
        end.to_not publish("webhookdb.developeralert.emitted")
      end
      expect(logs).to have_a_line_matching(/"message":"procmon"/)
      expect(logs).to have_a_line_matching(
        /"mem_used":123456789,"mem_perc_used":45/,
      )
    end

    it "warns on high memory usage" do
      expect(Sys::Memory).to receive(:used).and_return(123_456_789).twice
      expect(Sys::Memory).to receive(:load).and_return(99).twice
      logs = capture_logs_from(described_class.logger, level: :info, formatter: :json) do
        described_class.check
      end
      expect(logs).to have_a_line_matching(/"message":"procmon"/)
      expect(logs).to have_a_line_matching(
        /"mem_used":123456789,"mem_perc_used":99/,
      )

      expect do
        described_class.check
      end.to publish("webhookdb.developeralert.emitted").with_payload(
        contain_exactly(
          {
            "subsystem" => "Process Monitor (Memory)",
            "emoji" => ":brain:",
            "fallback" => "Host: web1, Memory Used: 0.1 GB, Memory % Used: 99%",
            "fields" => [
              {"title" => "Host", "value" => "web1", "short" => true},
              {"title" => "Memory Used", "value" => "0.1 GB", "short" => true},
              {"title" => "Memory % Used", "value" => "99%", "short" => true},
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
              {"title" => "Used Memory", "value" => "800MB", "short" => true},
              {"title" => "Used Memory RSS", "value" => "805MB", "short" => true},
              {"title" => "Available Memory", "value" => "1GB", "short" => true},
              {"title" => "Peak Memory", "value" => "810MB", "short" => true},
            ],
          },
        ),
      )
    end

    it "logs sidekiq jobs" do
      logs = capture_logs_from(described_class.logger, level: :info, formatter: :json) do
        expect do
          described_class.check
        end.to_not publish("webhookdb.developeralert.emitted")
      end
      expect(logs).to have_a_line_matching(/"message":"procmon"/)
      expect(logs).to have_a_line_matching(
        /"sidekiq_running_jobs":0,"sidekiq_slow_jobs":0/,
      )
    end

    it "does not warn about slow sidekiq jobs if under the count/age threshold" do
      expect(described_class).to receive(:sidekiq_work).
        and_yield(Sidekiq::Work.new("5h", "", {"run_at" => 5.hours.ago.to_i})).
        and_yield(Sidekiq::Work.new("1m", "", {"run_at" => 1.minute.ago.to_i})).
        and_yield(Sidekiq::Work.new("6h", "", {"run_at" => 6.hours.ago.to_i})).
        and_yield(Sidekiq::Work.new("2m", "", {"run_at" => 2.minutes.ago.to_i})).
        and_yield(Sidekiq::Work.new("1h", "", {"run_at" => 1.hour.ago.to_i}))

      logs = capture_logs_from(described_class.logger, level: :info, formatter: :json) do
        expect do
          described_class.check
        end.to_not publish("webhookdb.developeralert.emitted")
      end
      expect(logs).to have_a_line_matching(/"message":"procmon"/)
      expect(logs).to have_a_line_matching(
        /"sidekiq_running_jobs":5,"sidekiq_slow_jobs":2/,
      )
    end

    it "warns about slow Sidekiq jobs" do
      Timecop.freeze("2025-07-15T12:00:00Z") do
        expect(described_class).to receive(:sidekiq_work) do |&block|
          [
            [2, "minute"],
            [3, "minute"],
            [3, "hour"],
            [4, "hour"],
            [5, "hour"],
            [6, "hour"],
            [7, "hour"],
            [8, "hour"],
            [9, "hour"],
            [10, "hour"],
            [11, "hour"],
          ].shuffle.each do |n, unit|
            payload = {class: "Cls#{n}#{unit.first}", jid: "j#{n}#{unit.first}"}
            whash = {"run_at" => n.send(unit).ago.to_i, "payload" => payload.to_json}
            block.call(Sidekiq::Work.new("w#{n}#{unit.first}", "", whash))
          end
        end

        expect do
          described_class.check
        end.to publish("webhookdb.developeralert.emitted").with_payload(
          contain_exactly(
            {
              "subsystem" => "Process Monitor (Sidekiq)",
              "emoji" => ":ice_hockey_stick_and_puck:",
              # rubocop:disable Layout/LineLength
              "fallback" => "Running Jobs: 11, Slow Jobs: 6, j11h: Cls11h / 11 hours, j10h: Cls10h / 10 hours, j9h: Cls9h / 9 hours, j8h: Cls8h / 8 hours, j7h: Cls7h / 7 hours, j6h: Cls6h / 6 hours",
              # rubocop:enable Layout/LineLength
              "fields" => [
                {"title" => "Running Jobs", "value" => "11", "short" => true},
                {"title" => "Slow Jobs", "value" => "6", "short" => true},
                {"title" => "j11h", "value" => "`Cls11h` / 11 hours", "short" => false},
                {"title" => "j10h", "value" => "`Cls10h` / 10 hours", "short" => false},
                {"title" => "j9h", "value" => "`Cls9h` / 9 hours", "short" => false},
                {"title" => "j8h", "value" => "`Cls8h` / 8 hours", "short" => false},
                {"title" => "j7h", "value" => "`Cls7h` / 7 hours", "short" => false},
                {"title" => "j6h", "value" => "`Cls6h` / 6 hours", "short" => false},
              ],
            },
          ),
        )
      end
    end

    it "does not run singleton checks if the host name does not match the regex (DYNO env var)" do
      described_class.reset_configuration(singleton_hostname_regex: /web\.1/)
      ENV["DYNO"] = "web.2"

      logs = capture_logs_from(described_class.logger, level: :info, formatter: :json) do
        described_class.check
      end
      expect(logs).to_not have_a_line_matching(/sidekiq_running_jobs/)
    end

    it "does not run singleton checks if the host name does not match the regex (Socket.hostname)" do
      described_class.reset_configuration(singleton_hostname_regex: /web\.1/)
      ENV.delete("DYNO")
      expect(Socket).to receive(:gethostname).and_return("web.2")

      logs = capture_logs_from(described_class.logger, level: :info, formatter: :json) do
        described_class.check
      end
      expect(logs).to_not have_a_line_matching(/sidekiq_running_jobs/)
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
