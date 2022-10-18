# frozen_string_literal: true

require "webhookdb/typed_struct"

class Webhookdb::Services
  extend Webhookdb::MethodUtilities

  SERVICES_DIR = Pathname(__FILE__).dirname + "services"
  PLUGIN_DIR = Pathname(__FILE__).dirname + "services_ext"

  class InvalidService < StandardError; end

  class CredentialsMissing < StandardError; end

  # In the Descriptor struct, the value for :feature_roles is used in
  # our feature flagging functionality. It should default to [],
  # but other possible values to be included in the array are:
  #    -'internal' e.g. our fake integration
  #    -'unreleased' for works in progress
  #    -'beta' if we don't want most people to have access
  class Descriptor < Webhookdb::TypedStruct
    # @!attribute name
    #   @return [String]
    # @!attribute ctor
    #   @return [Proc]
    # @!attribute feature_roles
    #   @return [Array<String>]
    # @!attribute resource_name_singular
    #   @return [String]
    # @!attribute resource_name_plural
    #   @return [String]
    # @!attribute dependency_descriptor
    #   @return [Webhookdb::Services::Descriptor]
    attr_reader :name,
                :ctor,
                :resource_name_singular,
                :resource_name_plural,
                :feature_roles,
                :dependency_descriptor

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

    # @return [Webhookdb::Services::Descriptor]
    def registered_service(name)
      return @registered[name]
    end

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
