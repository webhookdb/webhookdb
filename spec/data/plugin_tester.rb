# frozen_string_literal: true

class Webhookdb::Services::PluginTester < Webhookdb::Services::Base
  def self.descriptor
    return Webhookdb::Services::Descriptor.new(
      name: "plugin_tester",
      ctor: ->(sint) { Webhookdb::Services::PluginTester.new(sint) },
      resource_name_singular: "PluginTester",
      feature_roles: [],
    )
  end
end
