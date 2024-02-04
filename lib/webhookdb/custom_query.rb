# frozen_string_literal: true

class Webhookdb::CustomQuery < Webhookdb::Postgres::Model(:custom_queries)
  plugin :timestamps

  CLI_EDITABLE_FIELDS = ["description", "sql", "public"].freeze
  DOCS_URL = "https://docs.webhookdb.com/docs/integrating/saved-queries.html"

  many_to_one :organization, class: "Webhookdb::Organization"
  many_to_one :created_by, class: "Webhookdb::Customer"

  alias public? public
  def private? = !self.public?

  def before_create
    self[:opaque_id] ||= Webhookdb::Id.new_opaque_id("cq")
    super
  end
end
