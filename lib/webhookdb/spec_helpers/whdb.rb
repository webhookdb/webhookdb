# frozen_string_literal: true

require "webhookdb/spec_helpers"

# Set :whdbisolation metadatabase. Use the isolation mode, or :reset to just reset config
# before and after the spec.
module Webhookdb::SpecHelpers::Whdb
  def self.included(context)
    context.before(:each) do |example|
      isomode = example.metadata[:whdbisolation]
      Webhookdb::Organization::DbBuilder.isolation_mode = isomode if isomode.is_a?(String)
      Webhookdb::Organization::DbBuilder.reset_configuration if isomode == :reset
    end

    context.after(:each) do |example|
      if (mode = example.metadata[:whdbisolation])
        Webhookdb::Organization.dataset.each(&:remove_related_database) if mode != :reset
        Webhookdb::Organization::DbBuilder.reset_configuration
      end
    end

    super
  end

  module_function def assign_connection_urls(o, **more)
    u = Webhookdb::Organization::DbBuilder.available_server_urls.sample
    raise "no server url?" if u.blank?
    o.update(
      readonly_connection_url_raw: u,
      admin_connection_url_raw: u,
      **more,
    )
  end
end
