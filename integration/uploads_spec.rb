# frozen_string_literal: true

require "webhookdb/aws"

RSpec.describe "uploads", :integration, pending: "Add AWS creds and create bucket" do
  it "can upload to a presigned URL" do
    auth_customer
    response = post("/v1/uploads/sign_url?bucket=Webhookdb-public-1&prefix=testing&filename=testing.txt")
    expect(response).to party_status(200)
    expect(response).to party_response(
      match(
        # rubocop:disable Layout/LineLength
        url: match(%r{https://webhookdb-public-1\.s3\.us-west-\d\.amazonaws.com/[a-z]+/testing/[a-z0-9]+-testing.txt\?}),
        # rubocop:enable Layout/LineLength
      ),
    )

    url = response.parsed_response["url"]
    response = HTTParty.put(url, body: "hello world", headers: {"content-type" => "text/plain"})
    expect(response).to party_status(200)

    parsed_uri = Webhookdb::AWS.s3.parse_uri(url)

    body_from_private = Webhookdb::AWS.s3.get_string(parsed_uri[:bucket], parsed_uri[:key])
    expect(body_from_private).to eq("hello world")

    public_url = url.split("?").first
    s3_pub_resp = HTTParty.get(public_url)
    expect(s3_pub_resp).to party_status(200)
    expect(s3_pub_resp.to_s).to eq("hello world")
  end
end
