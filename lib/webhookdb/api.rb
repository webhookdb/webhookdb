# frozen_string_literal: true

require "grape"

require "webhookdb"
require "webhookdb/service"

# API is the namespace module for API resources.
module Webhookdb::API
  require "webhookdb/api/entities"

  class V1 < Webhookdb::Service
    def self.inherited(subclass)
      super
      subclass.instance_eval do
        version "v1", using: :path
        format :json

        require "webhookdb/service/helpers"
        helpers Webhookdb::Service::Helpers

        helpers do
          def verified_customer!
            c = current_customer
            forbidden! unless c.phone_verified?
            return c
          end
        end
        before do
          Raven.tags_context(application: "public-api")
        end
      end
    end
  end
end
