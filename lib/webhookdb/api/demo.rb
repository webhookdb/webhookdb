# frozen_string_literal: true

require "webhookdb/api"

class Webhookdb::API::Demo < Webhookdb::API::V1
  resource :demo do
    post :data do
      merror!(403, "Demo mode is not enabled") unless Webhookdb::DemoMode.server_enabled?
      r = Webhookdb::DemoMode.build_demo_data
      status 200
      present(r)
    end
  end
end
