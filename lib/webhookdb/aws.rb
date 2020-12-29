# frozen_string_literal: true

require "aws-sdk-core"
require "appydays/configurable"

require "webhookdb" unless defined?(Webhookdb)

module Webhookdb::AWS
  extend Webhookdb::MethodUtilities
  include Appydays::Configurable
  include Appydays::Loggable

  require "webhookdb/aws/s3"
  singleton_attr_reader :s3

  # Some stuff doesn't work right with explicit config, so force-set the ENV
  configurable(:aws) do
    setting :access_key_id,
            "default-access",
            key: "AWS_ACCESS_KEY_ID",
            side_effect: ->(v) { ENV["AWS_ACCESS_KEY_ID"] = v }
    setting :secret_access_key,
            "default-secret",
            key: "AWS_SECRET_ACCESS_KEY",
            side_effect: ->(v) { ENV["AWS_SECRET_ACCESS_KEY"] = v }
    setting :region,
            "us-west-2",
            key: "AWS_REGION",
            side_effect: ->(v) { ENV["AWS_REGION"] = v }

    setting :default_s3_presign_expiration_secs, 300
    setting :default_s3_presign_acl, "private"

    after_configured do
      ::Aws.config.update(
        logger: self.logger,
      )

      @s3 = S3.new
    end
  end

  S3_BUCKET_OVERRIDES = {
    'webhookdb-public-1': {
      presign_acl: "public-read",
    },
  }.freeze

  # Return a hash of bucket-specific configuration where applicable, else global values.
  def self.bucket_configuration_for(bucket_name)
    config = S3_BUCKET_OVERRIDES[bucket_name.to_sym] || {}

    return [
      :presign_expiration_secs,
      :presign_acl,
    ].each_with_object({}) do |key, hash|
      hash[key] = config[key] || self.send("default_s3_#{key}")
    end
  end
end
