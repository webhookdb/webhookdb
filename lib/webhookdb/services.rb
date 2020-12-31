# frozen_string_literal: true

class Webhookdb::Services
  extend Webhookdb::MethodUtilities

  class InvalidService < RuntimeError; end

  singleton_attr_reader :registered
  @registered = {}

  def self.register(name, factory)
    self.registered[name] = factory
  end

  class Base
    attr_reader :service_integration

    def initialize(service_integration)
      @service_integration = service_integration
    end

    def webhook_http_request_verified?(request)
      raise NotImplementedError
    end

    def webhook_response_body
      return "ok"
    end

    def webhook_response_headers
      return {}
    end

    def webhook_response_content_type
      return "text/plain"
    end

    def create_table
      self.service_integration.db << self._create_table_sql
    end

    def _create_table_sql
      raise NotImplementedError
    end
  end

  def self.service_instance(service_integration)
    name = service_integration.service_name
    (cls = @registered[name]) or raise(InvalidService, name)
    return cls[service_integration]
  end
end

require "webhookdb/services/fake"
Webhookdb::Services.register("fake_v1", ->(sint) { Webhookdb::Services::Fake.new(sint) })
