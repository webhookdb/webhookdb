# frozen_string_literal: true

require "appydays/configurable"
require "appydays/loggable"
require "pg"
require "sequel"
require "tsort"

require "webhookdb"
require "webhookdb/admin"
require "webhookdb/postgres"
require "webhookdb/postgres/validations"
require "webhookdb/postgres/model_utilities"

# Initialize the Webhookdb::Postgres::Model class as an abstract model class (i.e.,
# without a default dataset). This prevents it from looking for a table called
# `models`, and makes inheriting it more straightforward.
# Thanks to Michael Granger and Jeremy Evans for the suggestion.
Webhookdb::Postgres::Model = Class.new(Sequel::Model)
Webhookdb::Postgres::Model.def_Model(Webhookdb::Postgres)

class Webhookdb::Postgres::Model
  include Appydays::Configurable
  extend Webhookdb::Postgres::ModelUtilities
  include Appydays::Loggable

  configurable(:webhookdb_db) do
    setting :uri, "postgres:/webhookdb_test", key: "DATABASE_URL"

    # rubocop:disable Naming/VariableNumber
    setting :encryption_key_0, "Tc3X6zkxXgZfHE81MFz2EILStV++BuQY"
    # rubocop:enable Naming/VariableNumber

    setting :extension_schema, "public"

    after_configured do
      self.connect(self.uri)
    end
  end

  # Add one or more extension +modules+ to the receiving class. This allows subsystems
  # like Orders, etc. to decorate models outside of their purview
  # without introducing unnecessary dependencies.
  #
  # Each one of the given +modules+ will be included in the receiving model class, and
  # if it also contains a constant called ClassMethods, the model class will be
  # also be extended with it.
  #
  # @example Add order methods to Webhookdb::Customer
  #
  #   module Webhookdb::Orders::CustomerExtensions
  #
  #       # Add some associations for Order models
  #       def included( model )
  #           super
  #           model.one_to_many :orders, Sequel[:app][:orders]
  #       end
  #
  #       def first_order
  #           self.orders.first
  #       end
  #
  #   end
  def self.add_extensions(*modules)
    self.logger.info "Adding extensions to %p: %p" % [self, modules]

    modules.each do |mod|
      include(mod)
      if mod.const_defined?(:ClassMethods)
        submod = mod.const_get(:ClassMethods)
        self.extend(submod)
      end
      if mod.const_defined?(:PrependedMethods)
        submod = mod.const_get(:PrependedMethods)
        prepend(submod)
      end
    end
  end

  plugin :column_encryption do |enc|
    enc.key 0, self.encryption_key_0
  end
end
