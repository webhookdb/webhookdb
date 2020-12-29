# frozen_string_literal: true

require "grape"

require "webhookdb"
require "webhookdb/service"

# API is the namespace module for Admin API resources.
module Webhookdb::AdminAPI
  require "webhookdb/admin_api/entities"

  class V1 < Webhookdb::Service
    def self.inherited(subclass)
      super
      subclass.instance_eval do
        version "v1", using: :path
        format :json
        prefix :admin

        content_type :csv, "text/csv"

        require "webhookdb/service/helpers"
        helpers Webhookdb::Service::Helpers

        auth(:admin)

        before do
          Raven.tags_context(application: "admin-api")
        end
      end
    end
  end
end
