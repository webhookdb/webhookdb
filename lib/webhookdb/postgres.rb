# frozen_string_literal: true

require "pg"
require "appydays/loggable"
require "sequel"
require "sequel/core"
require "sequel/adapters/postgres"

require "appydays/loggable/sequel_logger"
require "webhookdb"

module Webhookdb::Postgres
  extend Webhookdb::MethodUtilities
  include Appydays::Loggable

  class InTransaction < StandardError; end

  singleton_attr_accessor :unsafe_skip_transaction_check
  @unsafe_skip_transaction_check = false
  def self.check_transaction(db, error_msg)
    return true if self.unsafe_skip_transaction_check
    return true unless db.in_transaction?
    raise InTransaction, error_msg
  end

  # Sequel API -- load some global extensions and plugins
  Sequel.extension(
    :core_extensions,
    :core_refinements,
    :pg_array,
    :pg_array_ops,
    :pg_inet,
    :pg_inet_ops,
    :pg_json,
    :pg_json_ops,
    :pg_range,
    :pg_range_ops,
    :symbol_as_refinement,
  )
  Sequel::Model.plugin(:force_encoding, "UTF-8")

  # Require paths for model superclasses.
  SUPERCLASSES = [
    "webhookdb/postgres/model",
  ].freeze

  # Require paths for all Sequel models used by the app.
  MODELS = [
    "webhookdb/backfill_job",
    "webhookdb/customer",
    "webhookdb/customer/reset_code",
    "webhookdb/database_document",
    "webhookdb/idempotency",
    "webhookdb/logged_webhook",
    "webhookdb/message/body",
    "webhookdb/message/delivery",
    "webhookdb/oauth/session",
    "webhookdb/organization",
    "webhookdb/organization/database_migration",
    "webhookdb/organization_membership",
    "webhookdb/role",
    "webhookdb/service_integration",
    "webhookdb/subscription",
    "webhookdb/sync_target",
    "webhookdb/webhook_subscription",
    "webhookdb/webhook_subscription/delivery",
  ].freeze

  # If true, deferred model events publish immediately.
  # Should only be true for some types of testing.
  singleton_predicate_accessor :do_not_defer_events

  # The list of model superclasses (that get their own database connections)
  singleton_attr_reader :model_superclasses
  @model_superclasses = Set.new

  ### Register the given +superclass+ as a base class for a set of models, for operations
  ### which should happen on all the current database connections.
  def self.register_model_superclass(superclass)
    self.logger.debug "Registered model superclass: %p" % [superclass]
    self.model_superclasses << superclass
  end

  ##
  # The list of models that will be required once the database connection has been established.
  singleton_attr_reader :registered_models
  @registered_models = Set.new

  ### Add a +path+ to require once the database connection is set.
  def self.register_model(path)
    self.logger.debug "Registered model for requiring: %s" % [path]

    # If the connection's set, require the path immediately.
    if self.model_superclasses.any?(&:db)
      Appydays::Loggable[self].silence(:fatal) do
        require(path)
      end
    end

    self.registered_models << path
  end

  ### Require the model classes once the database connection has been established
  def self.require_models
    self.registered_models.each do |path|
      require path
    end
  end

  ### Call the block for each registered model superclass.
  def self.each_model_superclass(&)
    self.model_superclasses.each(&)
  end

  def self.each_model_class(&)
    self.each_model_superclass do |sc|
      sc.descendants.each(&)
    end
  end

  def self.run_all_migrations(target: nil)
    Sequel.extension :migration
    Webhookdb::Postgres.each_model_superclass do |cls|
      cls.install_all_extensions
      Sequel::Migrator.run(cls.db, "db/migrations", target:)
    end
  end

  # We can always register the models right away, since it does not have a side effect.
  MODELS.each do |m|
    self.register_model(m)
  end

  # After configuration, load superclasses. You may need these without loading models,
  # like if you need access to their DBs without loading them
  # (if their tables do not yet exist)
  def self.load_superclasses
    SUPERCLASSES.each do |sc|
      require(sc)
    end
  end

  # After configuration, require in the model superclass files,
  # to make sure their .db gets set and they're in model_superclasses.
  def self.load_models
    self.load_superclasses
    Appydays::Loggable[self].silence(:fatal) do
      self.require_models
    end
  end

  # Return 'Time.now' as an expression suitable for Sequel/SQL.
  # In some cases (like range @> expressions) you need to cast to a timestamptz explicitly,
  # the implicit cast isn't enough.
  # And because 'Time.now' is an external dependency, we should always use Sequel.delay,
  # to avoid any internal caching it will do,
  # like in association blocks: https://github.com/jeremyevans/sequel/blob/master/doc/association_basics.rdoc#block-
  def self.now_sql(&block)
    block ||= -> { Time.now }
    return Sequel.delay { Sequel.cast(block.call, :timestamptz) }
  end

  # Call block immediately if not deferring events; otherwise call it after db commit.
  def self.defer_after_commit(db, &block)
    raise LocalJumpError unless block
    return yield if self.do_not_defer_events?
    return db.after_commit(&block)
  end

  def self.defer_after_rollback(db, &block)
    raise LocalJumpError unless block
    return yield if self.do_not_defer_events?
    return db.after_rollback(&block)
  end
end
