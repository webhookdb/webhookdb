# frozen_string_literal: true

class Webhookdb::Organization::ErrorHandler < Webhookdb::Postgres::Model(:organization_error_handlers)
  include Webhookdb::Dbutil

  plugin :timestamps

  many_to_one :organization, class: "Webhookdb::Organization"
  many_to_one :created_by, class: "Webhookdb::Customer"
end
