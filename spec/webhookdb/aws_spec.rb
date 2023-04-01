# frozen_string_literal: true

require "webhookdb/aws"

RSpec.describe Webhookdb::AWS do
  before(:each) do
    described_class.region = "us-east-2"
    described_class.access_key_id = "access"
    described_class.secret_access_key = "sekrit"
    described_class.run_after_configured_hooks
  end

  describe "configuration" do
    it "sets up the AWS services for Webhookdb systems" do
      expect(ENV.fetch("AWS_REGION", nil)).to eq("us-east-2")
      expect(ENV.fetch("AWS_ACCESS_KEY_ID", nil)).to eq("access")
      expect(ENV.fetch("AWS_SECRET_ACCESS_KEY", nil)).to eq("sekrit")
    end
  end

  it "maps regions and locations" do
    expect(described_class::REGIONS_TO_LOCATIONS["us-west-2"]).to eq("US West (Oregon)")
    expect(described_class::LOCATIONS_TO_REGIONS["US West (Oregon)"]).to eq("us-west-2")
  end

  describe "logging" do
    it "logs in a structured format" do
      stub_request(:post, "https://sts.us-east-2.amazonaws.com/").
        to_return(status: 200, body: "", headers: {})

      logs = capture_logs_from(described_class.logger, level: :debug, formatter: :json) do
        described_class.sts_client.assume_role(
          role_arn: "arn:aws:iam::05408855555:role/Testing",
          role_session_name: "testing",
        )
      end
      expect(logs).to contain_exactly(
        include_json(
          level: "debug",
          name: "Webhookdb::AWS",
          message: "aws_assume_role",
          context: {
            aws_client: "STS",
            http_response_code: 200,
            elapsed: be_positive,
            request_params: "role_arn:\"arn:aws:iam::05408855555:role/Testing\",role_session_name:\"testing\"",
          },
        ),
      )
    end

    it "logs errors" do
      stub_request(:post, "https://sts.us-east-2.amazonaws.com/").
        to_return(status: 400, body: "", headers: {})

      logs = capture_logs_from(described_class.logger, level: :debug, formatter: :json) do
        expect do
          described_class.sts_client.assume_role(
            role_arn: "arn:aws:iam::05408855555:role/Testing",
            role_session_name: "testing",
          )
        end.to raise_error(Aws::STS::Errors::BadRequest)
      end
      expect(logs).to contain_exactly(
        include_json(
          level: "warn",
          name: "Webhookdb::AWS",
          message: "aws_assume_role",
          context: {
            aws_client: "STS",
            http_response_code: 400,
            elapsed: be_positive,
            request_params: "role_arn:\"arn:aws:iam::05408855555:role/Testing\",role_session_name:\"testing\"",
            error_class: "Aws::STS::Errors::BadRequest",
            error_message: "Aws::STS::Errors::BadRequest",
          },
        ),
      )
    end
  end
end
