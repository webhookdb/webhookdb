# frozen_string_literal: true

require "grape"

require "webhookdb/api"
require "webhookdb/services"

class Webhookdb::API::Services < Webhookdb::API::V1
  resource :services do
    desc "Returns a list of all available services."
    get do
      _customer = current_customer
      fake_entities = Webhookdb::Services.registered.keys.sort.map { |name| {name: name} }
      present_collection fake_entities, with: Webhookdb::API::ServiceEntity
    end
  end
end
