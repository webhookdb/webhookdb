# frozen_string_literal: true

require "webhookdb/postgres/model"

# A placeholder model for the magical mixin classes (imaged, ticketable, annotated).
# We can't easily test these things with non-Webhookdb::Postgres::Model subclasses,
# and we can't easily define Webhookdb::Postgres::Model subclasses as part of a spec/transaction.
# Even if Sequel can handle it, it creates some global state issues.
# Make sure this class is only required during specs, and not normal gem usage.
# It should never have a persistent table; only a table in the test database.
class Webhookdb::Postgres::TestingPixie < Webhookdb::Postgres::Model(:testing_pixies)
  plugin :money_fields, :price_per_unit
  plugin :tstzrange_fields, :active_during
end
