# frozen_string_literal: true

require "grape_entity"

require "webhookdb/service/entities"
require "webhookdb/api" unless defined? Webhookdb::API

module Webhookdb::API
  CurrentCustomerEntity = Webhookdb::Service::Entities::CurrentCustomer
  MoneyEntity = Webhookdb::Service::Entities::Money
  TimeRangeEntity = Webhookdb::Service::Entities::TimeRange

  class BaseEntity < Webhookdb::Service::Entities::Base; end

  class CustomerSettingsEntity < BaseEntity
    expose :name
  end

  class CLICustomerEntity < BaseEntity
    expose :email
    expose :indicator do |_instance, options|
      options[:indicator]
    end
  end
end
