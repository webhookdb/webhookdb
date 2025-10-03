# frozen_string_literal: true

RSpec.describe Webhookdb::Timezone, :db do
  it "upcases nonsense timzones", reset_configuration: described_class do
    described_class.nonsense_tzids = "abc Def"
    described_class.run_after_configured_hooks
    expect(described_class.nonsense_tzids).to eq("ABC DEF")
  end

  describe "windows_name_to_tz" do
    it "returns windows timezone names to unix tz names" do
      expect(described_class.windows_name_to_tz).to include(
        "AUS Central Standard Time" => Time.find_zone!("Australia/Darwin"),
      )
    end
  end

  describe "parse_time_with_tzid" do
    let(:ts) { "2000-01-01T12:00:00" }

    it "parses regular timezones" do
      expect(
        described_class.parse_time_with_tzid(ts, "America/New_York"),
      ).to contain_exactly(match_time("2000-01-01T12:00:00-05"), true)
    end

    it "parses zones with dashes" do
      expect(
        described_class.parse_time_with_tzid(ts, "America-New_York"),
      ).to contain_exactly(match_time("2000-01-01T12:00:00-05"), true)
    end

    it "parses offsets" do
      expect(
        described_class.parse_time_with_tzid(ts, "GMT-0500"),
      ).to contain_exactly(match_time("2000-01-01T12:00:00-05"), true)
      expect(
        described_class.parse_time_with_tzid(ts, "UTC-0500"),
      ).to contain_exactly(match_time("2000-01-01T12:00:00-05"), true)
      expect(
        described_class.parse_time_with_tzid(ts, "UTC+0500"),
      ).to contain_exactly(match_time("2000-01-01T12:00:00+05"), true)
      expect(
        described_class.parse_time_with_tzid(ts, "UTC-05"),
      ).to contain_exactly(match_time("2000-01-01T12:00:00-05"), true)
    end

    it "parses utc" do
      expect(
        described_class.parse_time_with_tzid(ts, "GMT"),
      ).to contain_exactly(match_time("2000-01-01T12:00:00Z"), true)
      expect(
        described_class.parse_time_with_tzid(ts, "UTC"),
      ).to contain_exactly(match_time("2000-01-01T12:00:00Z"), true)
    end

    it "warns about invalid timezones", :async do
      expect do
        expect(
          described_class.parse_time_with_tzid(ts, "invalid-tz"),
        ).to contain_exactly(match_time("2000-01-01T12:00:00Z"), false)
      end.to publish("webhookdb.developeralert.emitted").with_payload(
        contain_exactly(
          {
            subsystem: "Timezone Database",
            emoji: ":world_map:",
            fallback: "Invalid TZID: invalid-tz. Update tzinfo-data gem, or add this to TIMEZONE_NONSENSE_TZIDS.",
            fields: [
              {title: "Timezone ID", value: "invalid-tz", short: true},
              {title: "Time string", value: "2000-01-01T12:00:00", "short" => true},
              {title: "Action", value: "Update tzinfo-data gem, or add this ID to TIMEZONE_NONSENSE_TZIDS config."},
            ],
          }.as_json,
        ),
      )
    end

    it "does not warn about nonsense timezones", :async, reset_configuration: described_class do
      described_class.nonsense_tzids = "Foo invalid-TZ bar".upcase
      expect do
        expect(
          described_class.parse_time_with_tzid(ts, "invalid-tz"),
        ).to contain_exactly(match_time("2000-01-01T12:00:00Z"), false)
      end.to_not publish("webhookdb.developeralert.emitted")
    end
  end
end
