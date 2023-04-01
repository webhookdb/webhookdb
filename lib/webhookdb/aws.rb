# frozen_string_literal: true

require "aws-sdk-core"
require "aws-sdk-sts"
require "appydays/configurable"

require "webhookdb" unless defined?(Webhookdb)

module Webhookdb::AWS
  extend Webhookdb::MethodUtilities
  include Appydays::Configurable
  include Appydays::Loggable

  class ShimLogger
    def initialize(logger, operation_prefix: "aws_", level: :debug, error_level: :warn)
      @logger = logger
      @param_formatter = ::Aws::Log::ParamFormatter.new({})
      @param_filter = ::Aws::Log::ParamFilter.new({})
      @operation_prefix = operation_prefix
      @level = level
      @error_level = error_level
    end

    # Logger method. Receives the unformatted response form the shim formatter,
    # and logs a structured log.
    # @param [Seahorse::Client::Response] response
    def logshim(response)
      level = @level
      msg = @operation_prefix + response.context.operation_name.to_s
      params = response.context.params
      type = response.context.operation.input.shape.struct_class
      ctx = {
        aws_client: (response.context.client.class.name || "").delete_prefix("Aws::").delete_suffix("::Client"),
        http_response_code: response.context.http_response.status_code,
        elapsed: response.context[:logging_completed_at] - response.context[:logging_started_at],
        request_params: @param_formatter.summarize(@param_filter.filter(params, type)),
      }
      ctx[:retries] = response.context.retries if response.context.retries.positive?
      if response.error
        level = @error_level
        ctx[:error_class] = response.error.class.name
        ctx[:error_message] = response.error.message
      end
      @logger.send(level, msg, ctx)
    end
  end

  class ShimFormatter
    # Normally this must return a string, but we need to have it return a raw response
    # for use in the shim logger.
    # @param [Seahorse::Client::Response] response
    # @return [String]
    def format(response)
      # noinspection RubyMismatchedReturnType
      return response
    end
  end

  singleton_attr_reader :sts_client

  configurable(:aws) do
    # WebhookDB's AWS Account ID.
    # Used for things like cross-account role assumption.
    setting :external_account_id, "054088425385"

    # Some stuff doesn't work right with explicit config, so force-set the ENV
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

    after_configured do
      ::Aws.config.update(
        logger: ShimLogger.new(self.logger),
        log_formatter: ShimFormatter.new,
        log_level: :logshim,
      )

      @sts_client = Aws::STS::Client.new
    end
  end

  REGIONS_TO_LOCATIONS = Aws.partitions.each_with_object({}) do |partition, h|
    partition.regions.each do |region|
      h[region.name] = region.description
    end
  end.freeze
  LOCATIONS_TO_REGIONS = REGIONS_TO_LOCATIONS.to_a.map(&:reverse!).to_h.freeze
end
