# frozen_string_literal: true

require "webhookdb/api/uploads"

RSpec.describe Webhookdb::API::Uploads, :db do
  include Rack::Test::Methods

  let(:app) { described_class.build_app }

  describe "POST /v1/uploads/sign_url" do
    it "401s if there is no authenticated customer" do
      post "/v1/uploads/sign_url?bucket=my-bucket&filename=testing"

      expect(last_response).to have_status(401)
    end

    it "returns a hash for given url to presign" do
      login_as(Webhookdb::Fixtures.customer.create)

      post "/v1/uploads/sign_url?bucket=my-bucket&prefix=testing&filename=test.txt"

      expect(last_response).to have_status(200)

      # rubocop:disable Layout/LineLength
      url_regexp = %r{https://my-bucket\.s3\.us-.*-.*\.amazonaws\.com/test/testing/[a-z0-9]+-test\.txt\?.*X-Amz-Algorithm=}
      # rubocop:enable Layout/LineLength
      expect(last_response).to have_json_body.
        that_includes(url: match(url_regexp))
    end
  end
end
