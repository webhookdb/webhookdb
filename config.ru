# frozen_string_literal: true

lib = File.expand_path("lib", __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

require "webhookdb"
Webhookdb.load_app

require "grape"
require "grape_logging"
require "grape-swagger"
require "rack/cors"
require "rack/lint"

require "webhookdb/api"
require "webhookdb/async"
require "webhookdb/service"

require "webhookdb/api/auth"
require "webhookdb/api/db"
require "webhookdb/api/me"
require "webhookdb/api/organizations"
require "webhookdb/api/service_integrations"
require "webhookdb/api/services"
require "webhookdb/api/system"
require "webhookdb/api/uploads"

require "webhookdb/admin_api/auth"
require "webhookdb/admin_api/message_deliveries"
require "webhookdb/admin_api/roles"
require "webhookdb/admin_api/customers"

module Webhookdb::App
  class API < Webhookdb::Service
    mount Webhookdb::API::Auth
    mount Webhookdb::API::Db
    mount Webhookdb::API::Me
    mount Webhookdb::API::Organizations
    mount Webhookdb::API::ServiceIntegrations
    mount Webhookdb::API::Services
    mount Webhookdb::API::System
    mount Webhookdb::API::Uploads

    mount Webhookdb::AdminAPI::Auth
    mount Webhookdb::AdminAPI::MessageDeliveries
    mount Webhookdb::AdminAPI::Roles
    mount Webhookdb::AdminAPI::Customers

    add_swagger_documentation if ENV["RACK_ENV"] == "development"
  end
end

Webhookdb::Async.register_subscriber
run Webhookdb::App::API.build_app
