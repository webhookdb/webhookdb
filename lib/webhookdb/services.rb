# frozen_string_literal: true

class Webhookdb::Services
  extend Webhookdb::MethodUtilities

  class InvalidService < RuntimeError; end

  singleton_attr_reader :registered
  @registered = {}

  def self.register(name, factory)
    self.registered[name] = factory
  end

  # Return a new service instance for the given integration.
  #
  # @param service_integration [Webhookdb::ServiceIntegration]
  # @return [Webhookdb::Services::Base]
  def self.service_instance(service_integration)
    name = service_integration.service_name
    (cls = @registered[name]) or raise(InvalidService, name)
    return cls[service_integration]
  end
end

require "webhookdb/services/column"
require "webhookdb/services/base"
require "webhookdb/services/fake"
Webhookdb::Services.register("fake_v1", ->(sint) { Webhookdb::Services::Fake.new(sint) })
