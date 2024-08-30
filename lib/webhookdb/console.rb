# frozen_string_literal: true

require "webhookdb"

module Webhookdb::Console
  extend Webhookdb::MethodUtilities

  class Error < Webhookdb::WebhookdbError; end

  class UnsafeOperation < Error; end

  class ForbiddenOperation < Error; end

  singleton_attr_accessor :unsafe_mode
  @unsafe_mode = false

  singleton_attr_accessor :original_execute
  @original_execute = nil

  def self.enable_safe_mode
    Webhookdb::Console.original_execute = Webhookdb::Postgres::Model.db.method(:execute)
    Webhookdb::Postgres::Model.db.define_singleton_method(:execute) do |*args, &block|
      sql = args.first

      includes_where = sql.include?(" WHERE ")
      is_update = sql.start_with?("UPDATE ")
      is_delete = sql.start_with?("DELETE FROM")

      raise ForbiddenOperation, "TRUNCATE is forbidden" if sql.start_with?("TRUNCATE TABLE")

      raise ForbiddenOperation, "UPDATE without a WHERE is forbidden" if
        is_update && !includes_where

      raise ForbiddenOperation, "DELETE without a WHERE is forbidden" if
        is_delete && !includes_where

      raise UnsafeOperation, "DELETE is permitted only in an UNSAFE block" if
        is_delete && includes_where && !Webhookdb::Console.unsafe_mode

      Webhookdb::Console.original_execute.call(*args, &block)
    end
  end

  def self.disable_safe_mode
    Webhookdb::Postgres::Model.db.define_singleton_method(:execute, &Webhookdb::Console.original_execute)
  end

  def self.unsafe(&block)
    raise LocalJumpError, "unsafe must be called with a block (do ... end)" unless block
    self.unsafe_mode = true
    begin
      Webhookdb::Postgres::Model.db.transaction(&block)
    ensure
      self.unsafe_mode = false
    end
  end

  def self.console_logger(ev)
    Webhookdb.logger.info "ConsoleLogger: [%s] %s %p" % [ev.id, ev.name, ev.payload]
  end

  module MainMethods
    def unsafe(&)
      return Webhookdb::Console.unsafe(&)
    end

    def disconnect_db
      Webhookdb::Customer.db.disconnect
    end
  end
end
