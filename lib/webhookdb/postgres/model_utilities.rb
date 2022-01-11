# frozen_string_literal: true

require "tsort"
require "pg"
require "webhookdb/postgres"

# A collection of utilities that can be added to model superclasses.
module Webhookdb::Postgres::ModelUtilities
  include TSort

  # Extension callback -- register the +model_class+ with Webhookdb::Postgres.
  def self.extended(model_class)
    super

    # Sequel::Model API -- load some plugins
    model_class.plugin(:dirty)
    model_class.plugin(:json_serializer)
    model_class.plugin(:many_through_many)
    model_class.plugin(:subclasses)
    model_class.plugin(:tactical_eager_loading)
    model_class.plugin(:update_or_create)
    model_class.plugin(:validation_helpers)

    model_class.include(Appydays::Loggable)
    model_class.extend(ClassMethods)
    model_class.include(InstanceMethods)
    model_class.dataset_module(DatasetMethods)
    model_class.include(Webhookdb::Postgres::Validations)

    Webhookdb::Postgres.register_model_superclass(model_class)
  end

  module ClassMethods
    # The application name, set on database connections.
    attr_reader :appname

    # Set up some things on new database connections.
    def db=(newdb)
      self.logger.debug "Setting db %p" % [newdb]
      newdb.sql_log_level = :debug
      newdb.logger = self.logger
      newdb.log_warn_duration = self.slow_query_seconds

      newdb.extension(:pagination)
      newdb.extension(:pg_json)
      newdb.extension(:pg_inet)
      newdb.extension(:pg_array)
      newdb.extension(:pg_streaming)
      newdb.extension(:pg_range)
      newdb.extension(:pg_interval)
      newdb.extension(:pg_triggers)
      newdb.extension(:pretty_table)

      super

      self.descendents.each do |subclass|
        subclass.db = newdb
      end
    end

    # Set the PostgreSQL application name to +name+ to allow per-application connection
    # tracking and other fun stuff.
    def appname=(name)
      @appname = name
      self.update_connection_appname
    end

    # Set the connection's application name if there is one.
    def update_connection_appname
      return unless self.db
      self.logger.debug "Setting application name to %p" % [self.appname]
      self.db.synchronize do |conn|
        escaped = conn.escape_string(self.appname)
        conn.exec("SET application_name TO '%s'" % [escaped])
      end
    end

    # Fetch a model class by its +classname+. This can be the fully-qualified
    # name, or just the bit after 'Webhookdb::'.
    def by_name(classname)
      return self.descendents.find do |cl|
        cl.name&.end_with?(classname)
      end
    end

    # Return the Array of the schemas used by all descendents of the receiving
    # model class.
    def all_loaded_schemas
      return self.descendents.map(&:schema_name).uniq.compact
    end

    # Create a new schema named +name+ (if it doesn't already exist).
    def create_schema(name, &block)
      self.db.create_schema(name, if_not_exists: true)
      self.instance_eval(&block) if block
    end

    # Create the schema named +name+, dropping any previous schema by the same name.
    def create_schema!(name, &)
      self.drop_schema!(name)
      self.create_schema(name, &)
    end

    # Drop the empty schema named +name+ (if it exists).
    def drop_schema(name)
      self.db.drop_schema(name, if_exists: true)
    end

    # Drop the schema named +name+ and all of its tables.
    def drop_schema!(name)
      self.db.drop_schema(name, if_exists: true, cascade: true)
    end

    # Returns +true+ if a schema named +name+ exists.
    def schema_exists?(name=self.schema_name)
      ds = self.db[Sequel[:pg_catalog][:pg_namespace]].
        filter(nspname: name.to_s).
        select(:nspname)

      return ds.first ? true : false
    end

    # Return the name of the schema the receiving class is in.
    def schema_name
      schemaname, = self.db.send(:schema_and_table, self.table_name)
      return schemaname
    end

    def now_sql
      return Webhookdb::Postgres.now_sql
    end

    # TSort API -- yield each model class.
    def tsort_each_node(&)
      self.descendents.select(&:name).each(&)
    end

    # TSort API -- yield each of the given +model_class+'s dependent model
    # classes.
    def tsort_each_child(model_class)
      # Include (non-anonymous) parents other than Model
      non_anon_parents = model_class.ancestors[1..].
        select { |cl| cl < self }.
        select(&:name)
      # rubocop:disable Style/ExplicitBlockArgument
      non_anon_parents.each do |parentclass|
        yield(parentclass)
      end
      # rubocop:enable Style/ExplicitBlockArgument

      # Include associated classes for which this model class's table has a
      # foreign key
      model_class.association_reflections.each do |name, config|
        next if config[:polymorphic]

        associated_class = Object.const_get(config[:class_name])

        if config[:type] == :many_to_one
          self.logger.debug "  %p#%s is dependent on %p" %
            [model_class, name, associated_class]
          yield(associated_class)
        else
          self.logger.debug "  %p#%s is *not* dependent on %p" %
            [model_class, name, associated_class]
        end
      end
    end
  end

  # Like +find_or_create+, but will +find+ again if the +create+
  # call fails due to a +Sequel::UniqueConstraintViolation+,
  # which is usually caused by a race condition.
  def find_or_create_or_find(params, &)
    # Set a savepoint, because the DB error will abort the current transaction.
    self.db.transaction(savepoint: true) do
      return self.find_or_create(params, &)
    end
  rescue Sequel::UniqueConstraintViolation
    return self.find(params)
  end

  module InstanceMethods
    # Return a human-readable representation of the object as a String suitable for debugging.
    def inspect
      values = self.values.reject do |k, v|
        v.blank? || k.to_s.end_with?("_currency")
      end
      values = values.map do |(k, v)|
        k = k.to_s
        v = if v.is_a?(Time)
              self.inspect_time(v)
        elsif v.respond_to?(:db_type) && v.db_type.to_s == "tstzrange"
          "%s%s...%s%s" % [
            v.exclude_begin? ? "(" : "[",
            v.begin ? self.inspect_time(v.begin) : "nil",
            v.end ? self.inspect_time(v.end) : "nil",
            v.exclude_end? ? ")" : "]",
          ]
        elsif k.end_with?("_cents")
          accessor = k.match(/^([a-z_]+)_cents/)[1]
          k = accessor
          self.send(accessor).format
        else
          v.inspect
            end
        "#{k}: #{v}"
      end
      return "#<%p %s>" % [self.class, values.join(", ")]
    end

    def inspect_time(t)
      return t.in_time_zone(Time.zone).strftime("%Y-%m-%d %H:%M:%S")
    end

    # Return the objects validation errors as full messages joined with commas.
    def error_messages
      return self.errors.full_messages.join(", ")
    end

    # Return the string used as a topic for events sent from the receiving object.
    def event_prefix
      prefix = self.class.name or return # No events for anonymous classes
      return prefix.gsub("::", ".").downcase
    end

    # Publish an event from the receiving object of the specified +type+ and with the given +payload+.
    # This does *not* wait for the transaction to complete, so subscribers may not be able to observe
    # any model changes in the database. You probably want to use published_deferred.
    def publish_immediate(type, *payload)
      prefix = self.event_prefix or return
      Webhookdb.publish(prefix + "." + type.to_s, *payload)
    end

    # Publish an event in the current db's/transaction's +after_commit+ hook.
    def publish_deferred(type, *payload)
      Webhookdb::Postgres.defer_after_commit(self.db) do
        self.publish_immediate(type, *payload)
      end
    end

    # Take an exclusive lock on the receiver, ensuring nothing else has updated the object in the meantime.
    # If the updated_at changed from what's on the receiver, to after it acquired the lock, raise LockFailed.
    # Save changes and touch updated_at after calling the given block.
    def resource_lock!
      self.db.transaction do
        old_updated = self.round_time(self.updated_at)
        self.lock!
        new_updated = self.round_time(self.updated_at)
        raise Webhookdb::LockFailed if old_updated != new_updated
        result = yield(self)
        self.updated_at = Time.now
        self.save_changes
        return result
      end
    end

    # Round +Time+ t to remove nanoseconds, since Postgres can only store microseconds.
    protected def round_time(t)
      return nil if t.nil?
      return t.change(nsec: t.usec * 1000)
    end

    protected def now_sql
      return Webhookdb::Postgres.now_sql
    end

    # Sequel hook -- send an asynchronous event after the model is saved.
    def after_create
      super
      self.publish_deferred("created", self.id, self.values)
    end

    # Sequel hook -- send an asynchronous event after the save is committed.
    def after_update
      super
      self.publish_deferred("updated", self.id, self.previous_changes)
    end

    # Sequel hook -- send an event after a transaction that destroys the object is committed.
    def after_destroy
      super
      self.publish_deferred("destroyed", self.id, self.values)
    end
  end

  module DatasetMethods
    # Helper for applying multiple conditions for Sequel, where some can be nil.
    def reduce_expr(op_symbol, operands, method: :where)
      return self if operands.blank?
      present_ops = operands.select(&:present?)
      return self if present_ops.empty?
      full_op = present_ops.reduce(&op_symbol)
      return self.send(method, full_op)
    end

    # Call a block for each row in a dataset.
    # This is the same as paged_each or use_cursor.each, except that for each page,
    # rows are re-fetched using self.where(primary_key => [pks]).all to enable eager loading.
    #
    # (Note that paged_each does not do eager loading, which makes enumerating model associations very slow)
    def each_cursor_page(page_size: 500, order: :id, &block)
      raise LocalJumpError unless block
      raise "dataset requires a use_cursor method, class may need `extension(:pagination)`" unless
        self.respond_to?(:use_cursor)
      model = self.model
      pk = model.primary_key
      current_chunk_pks = []
      order = [order] unless order.respond_to?(:to_ary)
      self.naked.select(pk).order(*order).use_cursor(rows_per_fetch: page_size, hold: true).each do |row|
        current_chunk_pks << row[pk]
        next if current_chunk_pks.length < page_size
        page = model.where(pk => current_chunk_pks).order(*order).all
        current_chunk_pks.clear
        page.each(&block)
      end
      model.where(pk => current_chunk_pks).order(*order).all.each(&block)
    end

    # See each_cursor_page, but takes an additional action on each chunk of returned rows.
    # The action is called with pages of return values from the block when a page is is reached.
    # Each call to action should return nil, a result, or an array of results (nil results are ignored).
    #
    # The most common case is for ETL: process one dataset, map it in a block to return new row values,
    # and multi_insert it into a different table.
    def each_cursor_page_action(action:, page_size: 500, order: :id)
      raise LocalJumpError unless block_given?
      returned_rows_chunk = []
      self.each_cursor_page(page_size:, order:) do |instance|
        new_row = yield(instance)
        next if action.nil? || new_row.nil?
        new_row.respond_to?(:to_ary) ? returned_rows_chunk.concat(new_row) : returned_rows_chunk.push(new_row)
        if returned_rows_chunk.length >= page_size
          action.call(returned_rows_chunk)
          returned_rows_chunk.clear
        end
      end
      action&.call(returned_rows_chunk)
    end
  end
end
