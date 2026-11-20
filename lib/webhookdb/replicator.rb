# frozen_string_literal: true

require "appydays/configurable"
require "webhookdb/typed_struct"

class Webhookdb::Replicator
  include Appydays::Configurable
  extend Webhookdb::MethodUtilities

  configurable(:replicator) do
    setting :always_process_synchronously, false
  end

  PLUGIN_DIRNAME = "replicator_ext"
  PLUGIN_DIR = Pathname(__FILE__).dirname + PLUGIN_DIRNAME

  # Raised when there is no service registered for a name.
  class Invalid < Webhookdb::WebhookdbError; end

  # Raised when credentials to interact with a service are not set up.
  # Usually this is due to a missing dependency.
  class CredentialsMissing < Webhookdb::WebhookdbError; end

  # Raised when the columns or indices for a replicator are invalid.
  class BrokenSpecification < Webhookdb::WebhookdbError; end

  # Statically describe a replicator.
  class Descriptor < Webhookdb::TypedStruct
    # @!attribute name
    # Name of the replicator, like 'stripe_charge_v1'.
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
    #   @return [Webhookdb::Replicator::Descriptor]
    attr_reader :dependency_descriptor

    # True if this integration supports webhooks (real-time or user-built webhook payloads).
    attr_reader :supports_webhooks
    # True if this integration supports user-driven backfilling,
    # usually by paginating all resources.
    attr_reader :supports_backfill

    # If this integration has specific documentation,
    # link its url here. It is used to build custom error messages,
    # for example in case 'backfill' is called but not supported.
    attr_reader :documentation_url

    # If this integration uses /v1/install to set up,
    # or some other link like a marketplace URL,
    # provide it here. Note that you can add a redirect to Webhookdb::Apps::REDIRECTS
    # to provide a pretty, arbitrary URL.
    attr_reader :install_url

    # Markdown description of this replicator.
    attr_reader :description

    # URL pointing to the provider (not-WebhookDB) docs for this integration.
    attr_reader :api_docs_url

    # Is this an enterprise-only replicator?
    attr_reader :enterprise

    def documentable? = @documentable

    def initialize(
      name:,
      ctor:,
      resource_name_singular:,
      feature_roles:,
      supports_webhooks: false,
      supports_backfill: false,
      resource_name_plural: nil,
      dependency_descriptor: nil,
      api_docs_url: "",
      description: nil,
      enterprise: false,
      documentation_url: nil,
      install_url: nil,
      documentable: nil
    )
      raise ArgumentError, "must support one or both of webhooks and backfill" unless
        supports_webhooks || supports_backfill
      super(
        name:,
        resource_name_singular:,
        feature_roles:,
        supports_webhooks:,
        supports_backfill:,
        dependency_descriptor:,
        documentation_url:,
        api_docs_url:,
        install_url:,
        enterprise:
      )
      @ctor = ctor.is_a?(Class) ? ctor.method(:new) : ctor
      @resource_name_plural = resource_name_plural || "#{self.resource_name_singular}s"
      @description = description || "Replicate #{self.resource_name_plural} into your database."
      @documentable = documentable.nil? ? !self.name.start_with?("webhookdb_", "fake_", "theranest_") : documentable
    end

    def inspect
      return "#{self.class.name}(name: #{self.name})"
    end

    def ==(other)
      return self.class == other.class &&
          self.name == other.name &&
          self.resource_name_singular == other.resource_name_singular
    end

    alias supports_webhooks? supports_webhooks
    alias supports_backfill? supports_backfill
    alias enterprise? enterprise
    def webhooks_only? = self.supports_webhooks? && !self.supports_backfill?
    def backfill_only? = !self.supports_webhooks? && self.supports_backfill?
    def supports_webhooks_and_backfill? = self.supports_webhooks? && self.supports_backfill?
  end

  class IndexSpec < Webhookdb::TypedStruct
    attr_reader :columns, :where, :identifier
  end

  class << self
    # @return [Hash{String => Webhookdb::Replicator::Descriptor}]
    def registry
      return @registry ||= {}
    end

    def register(cls)
      desc = cls.descriptor
      raise TypeError, "descriptor must be a Descriptor, got #{desc.class.name}" unless desc.is_a?(Descriptor)
      self.registry[desc.name] = desc
    end

    # Return a new replicator for the given integration.
    #
    # @param service_integration [Webhookdb::ServiceIntegration]
    # @return [Webhookdb::Replicator::Base]
    def create(service_integration)
      name = service_integration.service_name
      descr = self.registered!(name)
      return descr.ctor.call(service_integration)
    end

    # Returns the service with the given name, or +nil+ if none is registered.
    # @return [Webhookdb::Replicator::Descriptor]
    def registered(name)
      return @registry[name]
    end

    # @raise [Webhookdb::Replicator::Invalid] When the name is invalid.
    # @return [Webhookdb::Replicator::Descriptor]
    def registered!(name)
      raise ArgumentError, "name cannot be blank" if name.blank?
      r = self.registered(name)
      return r if r
      raise Invalid, name
    end

    def load_replicators
      existing_descendants = Webhookdb::Replicator::Base.descendants
      ["replicator", PLUGIN_DIRNAME].each do |d|
        Gem.find_files(File.join("webhookdb/#{d}/*.rb")).each do |path|
          next if path.include?("/spec/")
          require path
        end
      end
      new_descendants = Webhookdb::Replicator::Base.descendants
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

    # @param sint [Webhookdb::ServiceIntegration]
    # @return [Webhookdb::ServiceIntegration,nil]
    def find_root(sint)
      max_depth = 15
      parent = sint.depends_on
      return sint if parent.nil?
      max_depth.times do
        return parent if parent.depends_on.nil?
        parent = parent.depends_on
      end
      return nil
    end

    # @param sint [Webhookdb::ServiceIntegration]
    # @return [Webhookdb::ServiceIntegration]
    def find_at_root!(sint, service_name:)
      root = self.find_root(sint)
      bad_auth = root&.service_name != service_name
      raise self::CredentialsMissing, "Could not find root integration for #{sint.inspect}" if bad_auth
      return root
    end

    # Two names can refer to the same index in the following scenario:
    # - Two replicators are created for the same service (R1, R2)
    # - R1 is deleted; R2 has its opaque_id set to R1.opaque_id
    # - This leads to R2's opaque id, and the prefix opaque_id on its indices, no longer matching.
    # - So as long as we know that an index points to R2's table,
    #   we should not care about its prefix.
    # - Use Replicator#align_index_names to fix this problem.
    #
    # IMPORTANT: This method accepts qualified Sequel identifiers
    # (Sequel[tablename][indexname]) so make sure the indices do not refer to different tables.
    # Because the opaque id is not considered, "svi_123_at_idx" and "svi_456_at_idx"
    # would be considered the same.
    #
    # @param idx1 [Sequel::SQL::QualifiedIdentifier]
    # @param idx2 [Sequel::SQL::QualifiedIdentifier]
    def refers_to_same_index?(idx1, idx2)
      return false unless idx1.table == idx2.table
      return true if idx1.column == idx2.column
      idx1name = idx1.column.to_s
      idx2name = idx2.column.to_s
      # Ids are encoded so can be 27-29 characters, we need to extract names with a regexp.
      regex = /^svi_[0-9a-z]+/
      return false unless (idx1match = idx1name.match(regex))
      return false unless (idx2match = idx2name.match(regex))
      return idx1name[idx1match.to_s.length..] == idx2name[idx2match.to_s.length..]
    end

    # Same as +refers_to_same_index?+, but names is an array of index names (does an +any?+ call).
    # @param idx [Sequel::SQL::QualifiedIdentifier]
    # @param indices [Array<Sequel::SQL::QualifiedIdentifier>]
    def refers_to_any_same_index?(idx, indices)
      return indices.any? { |n| self.refers_to_same_index?(n, idx) }
    end
  end

  require "webhookdb/replicator/state_machine_step"
  require "webhookdb/replicator/column"
  require "webhookdb/replicator/base"
  require "webhookdb/replicator/docgen"
  load_replicators
end
