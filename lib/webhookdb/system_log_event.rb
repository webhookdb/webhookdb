# frozen_string_literal: true

require "webhookdb/postgres/model"

class Webhookdb::SystemLogEvent < Webhookdb::Postgres::Model(:system_log_events)
  plugin :text_searchable, terms: [:title, :body]

  many_to_one :actor, class: "Webhookdb::Customer"
end
