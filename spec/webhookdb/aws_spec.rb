# frozen_string_literal: true

require_relative "../spec_helper"

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
      expect(ENV["AWS_REGION"]).to eq("us-east-2")
      expect(ENV["AWS_ACCESS_KEY_ID"]).to eq("access")
      expect(ENV["AWS_SECRET_ACCESS_KEY"]).to eq("sekrit")
    end
  end

  describe "#bucket_configuration_for" do
    it "returns defaults when bucket-specific configuration does not exist" do
      expect(described_class.bucket_configuration_for("potato-bucket")).to include(
        presign_expiration_secs: 300,
      )
    end

    it "returns bucket-specific configuration where applicable" do
      expect(described_class.bucket_configuration_for("blah")).to include(presign_acl: "private")
      expect(described_class.bucket_configuration_for("webhookdb-public-1")).to include(presign_acl: "public-read")
    end
  end

  describe "S3" do
    before(:each) do
      allow(described_class.s3).to receive(:client).and_return(Aws::S3::Client.new(stub_responses: true))
    end

    describe "#metadata" do
      it "returns metadata about an existing object" do
        metadata = described_class.s3.metadata("some-bucket", "some-key")
        expect(metadata[:content_length]).to eq(0) # default key and value in a stubbed response
      end
    end

    describe "#exists?" do
      it "is true if the object exists" do
        described_class.s3.client.stub_responses(:get_object_acl, Aws::PageableResponse)
        expect(described_class.s3.exists?("some-bucket", "some-key")).to be_truthy
      end

      it "is false if AWS raises a NoSuchKey error" do
        described_class.s3.client.stub_responses(:get_object_acl, "NoSuchKey")
        expect(described_class.s3.exists?("some-bucket", "some-key")).to be_falsey
      end
    end

    describe "#create_if_missing" do
      it "validates presence of bucket, key and body keys in param hash" do
        expect do
          described_class.s3.create_if_missing(bucket: "some-bucket")
        end.to raise_error(ArgumentError)
        expect do
          described_class.s3.create_if_missing(bucket: "some-bucket", key: "some_key")
        end.to raise_error(ArgumentError)
      end

      it "creates a new object when one does not exist" do
        described_class.s3.client.stub_responses(:get_object_acl, "NoSuchKey") # used by s3_object_exists?
        described_class.s3.client.stub_responses(:head_object, Aws::PageableResponse) # used by s3_object_metadata

        result = described_class.s3.create_if_missing(bucket: "some-bucket", key: "some-key", body: "some-body")
        expect(result).to be_a(Seahorse::Client::Response)
        expect(result).to eq(Aws::PageableResponse)
      end

      it "does not overwrite an existing object" do
        described_class.s3.client.stub_responses(:head_object, Aws::PageableResponse) # used by s3_object_metadata
        expect(described_class.s3.client).to_not receive(:put_object)

        result = described_class.s3.create_if_missing(bucket: "some-bucket", key: "some-key", body: "some-body")
        expect(result).to be_a(Seahorse::Client::Response)
        expect(result).to eq(Aws::PageableResponse)
      end
    end

    describe "#put" do
      it "validates presence of bucket, key and body keys in param hash" do
        expect { described_class.s3.put(bucket: "some-bucket") }.to raise_error(ArgumentError)
        expect { described_class.s3.put(bucket: "some-bucket", key: "some_key") }.to raise_error(ArgumentError)
      end

      it "puts an s3 object to the given bucket with the given key and body" do
        result = described_class.s3.put(bucket: "some-bucket", key: "some-key", body: "some-body")
        expect(result).to be_truthy
      end
    end

    describe "#delete" do
      it "deletes an s3 object in the given bucket with the given key and returns the response" do
        described_class.s3.client.stub_responses(:delete_object, Aws::S3::Types::DeleteObjectOutput.new)
        result = described_class.s3.delete("some-bucket", "some-key")
        expect(result).to be_a(Seahorse::Client::Response)
        expect(result.data).to be_a(Aws::S3::Types::DeleteObjectOutput)
      end
    end

    describe "#presigned_get_url" do
      it "returns an URL containing the bucket name and key name" do
        url = described_class.s3.presigned_get_url("frabjous", "day")
        expect(url).to start_with("https://frabjous.s3.us-east-2.amazonaws.com/day?X-Amz-Algorithm")
      end
    end

    describe "#get_string" do
      it "returns the body of an existing object" do
        body = described_class.s3.get_string("some-bucket", "some-key")
        expect(body).to be_a(String)
      end
    end

    describe "#get_stream" do
      it "returns the body of an existing object" do
        body = described_class.s3.get_stream("some-bucket", "some-key")
        expect(body).to be_a(StringIO)
      end
    end

    describe "#bucket_and_key_from_uri" do
      it "returns the bucket and key from an s3 URL" do
        url = "s3://potato/mashed.png"
        expect(described_class.s3.bucket_and_key_from_uri(url)).to eq(["potato", "mashed.png"])
      end

      it "returns the bucket and key from an HTTP URL" do
        url = "https://potato.s3.amazonaws.com/fld/mashed.png"
        expect(described_class.s3.bucket_and_key_from_uri(url)).to eq(["potato", "fld/mashed.png"])
      end

      it "returns the bucket and key from an HTTP URL with the region" do
        url = "https://potato.s3.us-east-2.amazonaws.com/fld/mashed.png"
        expect(described_class.s3.bucket_and_key_from_uri(url)).to eq(["potato", "fld/mashed.png"])
      end

      it "raises if the URL is not an s3 or HTTP URL" do
        expect do
          described_class.s3.bucket_and_key_from_uri("http://potato.com/mashed.jpg")
        end.to raise_error(ArgumentError)
      end
    end

    describe "#signed_url_from_uri" do
      it "raises if the uri is not an s3 uri" do
        expect do
          described_class.s3.signed_url_from_uri("http://potato.com/mashed.jpg")
        end.to raise_error(ArgumentError)
      end

      it "returns a signed url" do
        expect(described_class.s3.signed_url_from_uri("s3://potato/mashed.jpeg")).to start_with(
          "https://potato.s3.us-east-2.amazonaws.com/mashed.jpeg",
        )
      end

      it "handles signing options" do
        url = described_class.s3.signed_url_from_uri(
          "s3://potato/mashed.jpeg",
          response_content_disposition: "attachment",
        )
        expect(url).to include(
          "response-content-disposition=attachment",
        )
      end
    end

    describe "upload_url" do
      it "uploads non-s3 images to s3" do
        url = Faker::Webhookdb.image_url(filename: CGI.escape("special <-> CHARS"), ext: "png")

        get_req = stub_request(:get, url).
          and_return(status: 200, body: "", headers: {"Content-Type" => "image/jpeg"})
        expect(Webhookdb::AWS.s3).to receive(:put).once

        new_url = Webhookdb::AWS.s3.upload_url("my-prefix", "buckit", url)

        expected = %r{https://buckit\.s3\.amazonaws\.com/test/my-prefix/[a-z0-9]+-special-chars\.png}
        expect(new_url).to match(expected)
        expect(get_req).to have_been_made
      end

      it "uses a class name as the prefix if not a string" do
        url = Faker::Webhookdb.image_url

        stub_request(:get, url).
          and_return(status: 200, body: "", headers: {"Content-Type" => "image/jpeg"})
        expect(Webhookdb::AWS.s3).to receive(:put).once

        new_url = Webhookdb::AWS.s3.upload_url(Webhookdb::Customer, "buckit", url)

        expect(new_url).to include("/customer/")
      end

      it "leaves out an extension if the source has none" do
        url = "http://co.co/image"

        stub_request(:get, url).
          and_return(status: 200, body: "", headers: {"Content-Type" => "image/jpeg"})
        expect(Webhookdb::AWS.s3).to receive(:put).once

        new_url = Webhookdb::AWS.s3.upload_url(Webhookdb::Customer, "buckit", url)

        expect(new_url).to end_with("-image")
      end

      it "does not re-upload images on s3" do
        already_on_s3 = Faker::Webhookdb.s3_url
        new_url = Webhookdb::AWS.s3.upload_url(Webhookdb::Customer, "buckit", already_on_s3)
        expect(new_url).to eq(already_on_s3)
      end

      it "manipulates dropbox links to raw=1" do
        req = stub_request(:get, "https://www.dropbox.com/s/some-folder/my-image.png?raw=1").
          and_return(status: 200, body: "", headers: {"Content-Type" => "image/png"})
        expect(Webhookdb::AWS.s3).to receive(:put).once

        Webhookdb::AWS.s3.upload_url(Webhookdb::Customer, "buckit",
                                     "https://www.dropbox.com/s/some-folder/my-image.png?dl=0",)

        expect(req).to have_been_made
      end

      it "does not fail for malformed urls" do
        expect do
          Webhookdb::AWS.s3.upload_url(Webhookdb::Customer, "buckit", "/some-folder/my-image.png?dl=0")
        end.to raise_error(/be an absolute/)
      end
    end
  end
end
