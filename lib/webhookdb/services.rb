# frozen_string_literal: true

require "webhookdb/typed_struct"

class Webhookdb::Services
  extend Webhookdb::MethodUtilities

  SERVICES_DIR = Pathname(__FILE__).dirname + "services"
  PLUGIN_DIR = Pathname(__FILE__).dirname + "services_ext"

  # Raised when there is no service registered for a name.
  class InvalidService < StandardError; end

  # Raised when credentials to interact with a service are not set up.
  # Usually this is due to a missing dependency.
  class CredentialsMissing < StandardError; end

  # Statically describe a service integration.
  class Descriptor < Webhookdb::TypedStruct
    # @!attribute name
    # Name of the service, like 'stripe_charge_v1'.
    # Appears externally in many places, so must be meaningful.
    #   @return [String]
    attr_reader :name

    # @!attribute ctor
    # Method invoked with the +Webhookdb::ServiceIntegration+, and should return a new instance
    # of the integration. Can also be an object that responds to `new`.
    #   @return [Proc]
    attr_reader :ctor

    # @!attribute feature_roles
    # Used for feature flagging functionality.
    # Usually will be [], but other possible values are:
    # -'internal' e.g. our fake integration
    # -'unreleased' for works in progress
    # -'beta' if we don't want most people to have access
    #   @return [Array<String>]
    attr_reader :feature_roles

    # @!attribute resource_name_singular
    # Name of the resource, like "Acme Sprocket"
    #   @return [String]
    attr_reader :resource_name_singular

    # @!attribute resource_name_plural
    # Defaults to resource_name_singular+s.
    #   @return [String]
    attr_reader :resource_name_plural

    # @!attribute dependency_descriptor
    # The descriptor for the service this one depends on (the parent).
    #   @return [Webhookdb::Services::Descriptor]
    attr_reader :dependency_descriptor

    def initialize(
      name:,
      ctor:,
      resource_name_singular:,
      feature_roles:,
      resource_name_plural: nil,
      dependency_descriptor: nil
    )
      super(name:, resource_name_singular:, feature_roles:, dependency_descriptor:)
      @ctor = ctor.is_a?(Class) ? ctor.method(:new) : ctor
      @resource_name_plural = resource_name_plural || "#{self.resource_name_singular}s"
      self.feature_roles
    end

    def inspect
      return "#{self.class.name}(name: #{self.name})"
    end

    def ==(other)
      return self.class == other.class &&
          self.name == other.name &&
          self.resource_name_singular == other.resource_name_singular
    end
  end

  class << self
    # @return [Hash{String => Webhookdb::Services::Descriptor}]
    def registered
      return @registered ||= {}
    end

    def register(cls)
      desc = cls.descriptor
      raise TypeError, "descriptor must be a Descriptor, got #{desc.class.name}" unless desc.is_a?(Descriptor)
      self.registered[desc.name] = desc
    end

    # Return a new service instance for the given integration.
    #
    # @param service_integration [Webhookdb::ServiceIntegration]
    # @return [Webhookdb::Services::Base]
    def service_instance(service_integration)
      name = service_integration.service_name
      descr = self.registered_service!(name)
      return descr.ctor.call(service_integration)
    end

    # Returns the service with the given name, or +nil+ if none is registered.
    # @return [Webhookdb::Services::Descriptor]
    def registered_service(name)
      return @registered[name]
    end

    # @raise [Webhookdb::Services::InvalidService] When the name is invalid.
    # @return [Webhookdb::Services::Descriptor]
    def registered_service!(name)
      r = self.registered_service(name)
      return r if r
      raise InvalidService, name
    end

    def load_services
      existing_descendants = Webhookdb::Services::Base.descendants
      self._require_files(SERVICES_DIR)
      self._require_files(PLUGIN_DIR)
      new_descendants = Webhookdb::Services::Base.descendants
      newly_registered = new_descendants - existing_descendants
      newly_registered.each { |cls| self.register(cls) }
      return newly_registered
    end

    def _require_files(dir)
      splitter = "webhookdb/" + dir.to_s.rpartition("/").last
      dir.glob("*.rb").each do |path|
        base = path.basename.to_s[..-4]
        require("#{splitter}/#{base}")
      end
    end
  end

  require "webhookdb/services/state_machine_step"
  require "webhookdb/services/column"
  require "webhookdb/services/base"
  load_services
end
