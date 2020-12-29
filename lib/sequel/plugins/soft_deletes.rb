# frozen_string_literal: true

require "sequel"
require "sequel/model"

# Plugin for adding soft-delete to a model.
#
# == Example
#
# Defining a model class with a timestamp as the deletion flag:
#
#   class ACME::Customer < Sequel::Model(:customers)
#       plugin :soft_deletes, column: :deleted_at
#
# And in the schema:
#   create_table( :customers ) do
#       primary_key :id
#       timestamptz :deleted_at
#   end
#
module Sequel::Plugins::SoftDeletes
  # Default plugin options
  DEFAULT_OPTIONS = {
    column: :soft_deleted_at,
    omit_by_default: false,
  }.freeze

  def self.configure(model, opts=DEFAULT_OPTIONS)
    opts = DEFAULT_OPTIONS.merge(opts)
    column = opts[:column]
    model.soft_delete_column = column
    model.set_dataset(model.where(column => nil)) if opts[:omit_by_default]
  end

  module DatasetMethods
    def soft_deleted
      column = self.model.soft_delete_column
      exclude(column => nil)
    end

    def not_soft_deleted
      column = self.model.soft_delete_column
      where(column => nil)
    end
  end

  # Methods to extend Model classes with.
  module ClassMethods
    ##
    # The Array of field which are images, as Symbols
    attr_accessor :soft_delete_column
  end

  # Methods to extend Model instances with.
  module InstanceMethods
    ### Returns +true+ if this object should be considered deleted.
    def soft_deleted?
      column = self.class.soft_delete_column
      return self[column] ? true : false
    end

    alias is_soft_deleted? soft_deleted?

    ### Returns +true+ if the object is soft-deletable. By default, an
    ### object is soft-deletable if it has no +soft_deletion_blockers+.
    def soft_deletable?
      return self.soft_deletion_blockers.empty?
    end

    ### Soft-delete this instance.
    def soft_delete
      column = self.class.soft_delete_column

      self.db.transaction do
        supered_from_around = false
        self.around_soft_delete do
          supered_from_around = true
          raise_hook_failure(:before_soft_delete) unless self.before_soft_delete

          self.update(column => Time.now)

          self.after_soft_delete
        end
        raise_hook_failure(:around_soft_delete) unless supered_from_around
      end
    end

    ### Returns an array of conditions preventing soft-deletion. Default is an empty array.
    def soft_deletion_blockers
      return []
    end

    ### Remove soft-deletion blockers. Default soft-deletion raises NotImplementedError.
    def remove_soft_deletion_blockers
      raise NotImplementedError
    end

    ### Default 'before' soft-delete hook checks if object is soft-deletable.
    ### Aborts soft-deletion if it returns false.
    def before_soft_delete
      return self.soft_deletable?
    end

    ### Default (empty) 'around' soft-delete model hook.
    def around_soft_delete
      yield
    end

    ### Default (empty) 'after' soft-delete hook.
    def after_soft_delete; end

    ### Return the information for the soft-deletes column.
    def soft_delete_column
      return self.class.schema.columns.find do |col|
        col[:name] == self.class.soft_delete_column
      end
    end
  end
end
