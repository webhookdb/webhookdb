# frozen_string_literal: true

require "grape"
require "grape/validations/validators/base"

module Webhookdb::Service::Validators
  class UsPhone < ::Grape::Validations::Validators::Base
    def validate_param!(attr_name, params)
      val = params[attr_name]
      return if val.blank? && @allow_blank
      return if Webhookdb::PhoneNumber::US.valid?(val)
      raise Grape::Exceptions::Validation.new(
        params: [@scope.full_name(attr_name)],
        message: "must be a 10-digit US phone",
      )
    end
  end

  class DbIdentifier < ::Grape::Validations::Validators::Base
    def validate_param!(attr_name, params)
      val = params[attr_name]
      return if val.blank? && @allow_blank
      return if Webhookdb::DBAdapter.valid_identifier?(val)
      raise Grape::Exceptions::Validation.new(
        params: [@scope.full_name(attr_name)],
        message: "is not a valid database identifier for WebhookDB. " +
          Webhookdb::DBAdapter::INVALID_IDENTIFIER_MESSAGE,
      )
    end
  end
end
