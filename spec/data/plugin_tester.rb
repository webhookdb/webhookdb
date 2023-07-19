# frozen_string_literal: true

class Webhookdb::Replicator::PluginTester < Webhookdb::Replicator::Base
  def self.descriptor
    return Webhookdb::Replicator::Descriptor.new(
      name: "plugin_tester",
      ctor: ->(sint) { Webhookdb::Replicator::PluginTester.new(sint) },
      resource_name_singular: "PluginTester",
      feature_roles: [],
      supports_backfill: true,
    )
  end
end
