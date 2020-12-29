# frozen_string_literal: true

require "grape"

require "webhookdb/admin_api"

class Webhookdb::AdminAPI::Roles < Webhookdb::AdminAPI::V1
  resource :roles do
    desc "Return all roles, ordered by name"
    get do
      ds = Webhookdb::Role.dataset.order(:name)
      present_collection ds, with: Webhookdb::AdminAPI::RoleEntity
    end
  end
end
