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
        "AUS CENTRAL STANDARD TIME" => Time.find_zone!("Australia/Darwin"),
        "ATLANTIC STANDARD TIME" => Time.find_zone!("America/Halifax"),
      )
    end
  end

  describe "parse_time_with_tzid" do
    let(:summer) { "2000-07-01T12:00:00" }
    let(:ts) { "2000-01-01T12:00:00" }

    def testparse(s, tzid, expected, didparse)
      t, parsed = described_class.parse_time_with_tzid(s, tzid)
      expect(t).to match_time(expected)
      expect(parsed).to eq(didparse)
    end

    # rubocop:disable RSpec/NoExpectationExample

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

    it "parses windows timezones" do
      testparse(ts, "SA Western Standard Time", "2000-01-01T12:00:00-04", true)
      testparse(ts, " SA Western Standard Time\t", "2000-01-01T12:00:00-04", true)
      testparse(ts, "sa western standard time", "2000-01-01T12:00:00-04", true)
    end

    it "parses offsets" do
      testparse(ts, "GMT-0500", "2000-01-01T12:00:00-05", true)
      testparse(ts, "GMT-06:00", "2000-01-01T12:00:00-06", true)
      testparse(ts, "UTC-0500", "2000-01-01T12:00:00-05", true)
      testparse(ts, "UTC+0500", "2000-01-01T12:00:00+05", true)
      testparse(ts, "UTC-05", "2000-01-01T12:00:00-05", true)
    end

    it "parses named offsets" do
      testparse(ts, "(UTC-07:00) Arizona", "2000-01-01T12:00:00-07", true)
      testparse(ts, "(UTC+05:30) Chennai, Kolkata, Mumbai, New Delhi", "2000-01-01T12:00:00+0530", true)
      testparse(ts, "(UTC+00:00) Dublin, Edinburgh, Lisbon, London", "2000-01-01T12:00:00Z", true)
    end

    it "handles special case TZID offsets" do
      testparse(ts, "EST", "2000-01-01T12:00:00-05", true)
      testparse(ts, "EDT", "2000-01-01T12:00:00-04", true)
      testparse(ts, "Yukon Standard Time", "2000-01-01T12:00:00-08", true)
      testparse("2024-01-01T12:00:00-07", "Yukon Standard Time", "2024-01-01T12:00:00-07", true)
      testparse(ts, "(UTC) Coordinated Universal Time", "2000-01-01T12:00:00Z", true)
    end

    it "handles special case TZID names" do
      testparse(ts, "Eastern Standard Time", "2000-01-01T12:00:00-05", true)
      testparse(ts, "Eastern Standard Time 1", "2000-01-01T12:00:00-05", true)
      testparse(summer, "Eastern Standard Time", "2000-07-01T12:00:00-04", true)
      testparse(ts, "Eastern Time", "2000-01-01T12:00:00-05", true)
      testparse(ts, "Pacific Time (US & Canada), Tijuana", "2000-01-01T12:00:00-08", true)
    end

    it "handles standard/daylight format" do
      tzid = "GMT -0800 (Standard) / GMT -0700 (Daylight)"
      testparse(ts, tzid, "2000-01-01T12:00:00-08", true)
      testparse(summer, tzid, "2000-07-01T12:00:00-07", true)
    end

    it "canonicalizes casing" do
      testparse(ts, "America/Blanc-Sablon", "2000-01-01T12:00:00-04", true)
      testparse(ts, "America/Blanc-sablon", "2000-01-01T12:00:00-04", true)
      testparse(ts, "America/blanc-SABLON", "2000-01-01T12:00:00-04", true)
    end

    it "handles Etc" do
      testparse(ts, "Etc/GMT", "2000-01-01T12:00:00+00", true)
      testparse(ts, "Etc/Universal", "2000-01-01T12:00:00+00", true)
      # These are inverted, see: https://en.wikipedia.org/wiki/Tz_database#Area
      testparse(ts, "Etc/GMT-2", "2000-01-01T12:00:00+02", true)
      testparse(ts, "Etc/GMT-0", "2000-01-01T12:00:00+00", true)
      testparse(ts, "Etc/GMT+1", "2000-01-01T12:00:00-01", true)
      testparse(ts, "Etc/GMT+11", "2000-01-01T12:00:00-11", true)
    end

    it "ignores custom timezones and uuids" do
      testparse(ts, "c3566dec-0958-48d5-8c80-57fb6274ccb2", "2000-01-01T12:00:00Z", false)
      testparse(ts, "Customized Time Zone 1", "2000-01-01T12:00:00Z", false)
      testparse(ts, "Customized Time Zone", "2000-01-01T12:00:00Z", false)
      testparse(ts, "1", "2000-01-01T12:00:00Z", false)
    end

    it "strips tzone://" do
      testparse(ts, "tzone://Microsoft/Utc", "2000-01-01T12:00:00Z", true)
      testparse(ts, "tzone://Microsoft/Custom", "2000-01-01T12:00:00Z", false)
    end

    it "strips leading slashes" do
      testparse(ts, "/America/Los_Angeles", "2000-01-01T12:00:00-0800", true)
    end

    it "strips trailing years (due to malformed tzid line)" do
      testparse(ts, "Eastern Standard Time2025", "2000-01-01T12:00:00-0500", true)
      testparse(ts, "America/New_York2025", "2000-01-01T12:00:00-0500", true)
    end

    it "parses utc" do
      testparse(ts, "GMT", "2000-01-01T12:00:00Z", true)
      testparse(ts, "UTC", "2000-01-01T12:00:00Z", true)
    end

    [
      ["Singapore Standard Time", "2000-01-01T12:00:00+0800"],
      ["Central Daylight Time", "2000-07-01T12:00:00-0500", true],
      # Daylight time in southern hemisphere is northern winter months
      ["AUS Eastern Standard Time", "2000-01-01T12:00:00+1100"],
      ["AUS Eastern Standard Time", "2000-07-01T12:00:00+1000", true],
      ["GMT Standard Time", "2000-01-01T12:00:00+00:00"],
      ["Greenwich Standard Time", "2000-01-01T12:00:00+00:00"],
      ["US Eastern Standard Time", "2000-01-01T12:00:00-0500"],
      ["US America/New_York", "2000-01-01T12:00:00-0500"],
      ["AUS America/New_York", "2000-01-01T12:00:00-0500"],
    ].each do |(tzid, expected, dosummer)|
      it "parses #{tzid}#{' in summer' if dosummer}" do
        testparse(dosummer ? summer : ts, tzid, expected, true)
      end
    end

    it "warns about invalid timezones", :async do
      expect do
        testparse(ts, "invalid-tz", "2000-01-01T12:00:00Z", false)
      end.to publish("webhookdb.developeralert.emitted").with_payload(
        contain_exactly(
          {
            subsystem: "Timezone Database",
            emoji: ":world_map:",
            fallback: "Invalid TZID: invalid-tz. Update tzinfo-data gem, or add this to TIMEZONE_NONSENSE_TZIDS.",
            fields: [
              {title: "Timezone ID", value: '"invalid-tz"', short: true},
              {title: "Encoding", value: "UTF-8", short: true},
              {title: "Base64", value: "aW52YWxpZC10eg==", short: true},
              {title: "Time string", value: "2000-01-01T12:00:00", short: true},
              {title: "Action", value: "Update tzinfo-data gem, or add this ID to TIMEZONE_NONSENSE_TZIDS config."},
            ],
          }.as_json,
        ),
      )
    end

    it "does not warn about nonsense timezones", :async, reset_configuration: described_class do
      described_class.nonsense_tzids = "Foo invalid-TZ bar".upcase
      expect do
        testparse(ts, "invalid-tz", "2000-01-01T12:00:00Z", false)
      end.to_not publish("webhookdb.developeralert.emitted")
    end

    # rubocop:enable RSpec/NoExpectationExample
  end
end
