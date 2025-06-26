# frozen_string_literal: true

require "webhookdb/signalwire"

RSpec.describe Webhookdb::Signalwire do
  describe "send_sms", reset_configuration: described_class do
    it "sends the message" do
      described_class.sms_allowlist = ["*"]

      req = stub_request(:post, "https://space.signalwire.com/api/laml/2010-04-01/Accounts/proj/Messages.json").
        with(
          body: {"Body" => "hello", "From" => "+12223334444", "To" => "+14445556666"},
          headers: {
            "Accept" => "application/json",
            "Authorization" => "Basic cHJvajpzd2tleQ==",
            "Content-Type" => "application/x-www-form-urlencoded",
          },
        ).to_return(json_response({sid: "SWID123"}))

      got = described_class.send_sms(
        from: "+12223334444",
        to: "+14445556666",
        body: "hello",
        project_id: "proj",
        space_url: "space",
        api_key: "swkey",
        logger: nil,
      )
      expect(got).to eq({"sid" => "SWID123"})
      expect(req).to have_been_made
    end

    it "skips sending if the to number is not allowlisted" do
      got = described_class.send_sms(
        from: "+12223334444",
        to: "+14445556666",
        body: "hello",
        project_id: "proj",
        api_key: "swkey",
        logger: nil,
      )
      expect(got).to eq({"sid" => "skipped"})
    end
  end
end
