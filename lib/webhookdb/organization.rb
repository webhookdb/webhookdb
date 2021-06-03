# frozen_string_literal: true

require "webhookdb/postgres/model"

class Webhookdb::Organization < Webhookdb::Postgres::Model(:organizations)
  plugin :timestamps
  plugin :soft_deletes

  one_to_many :memberships, class: "Webhookdb::OrganizationMembership"
  one_to_many :service_integrations, class: "Webhookdb::ServiceIntegration"

  def before_create
    self.key ||= Webhookdb.to_slug(self.name)
    super
  end

  def self.create_if_unique(params)
    self.db.transaction(savepoint: true) do
      return Webhookdb::Organization.create(name: params[:name])
    end
  rescue Sequel::UniqueConstraintViolation
    return nil
  end
end
