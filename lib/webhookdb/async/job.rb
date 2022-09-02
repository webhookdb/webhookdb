# frozen_string_literal: true

require "sidekiq"

require "webhookdb/async"

module Webhookdb::Async::Job
  class Retry < StandardError
    attr_accessor :interval_or_timestamp

    def initialize(interval_or_timestamp)
      @interval_or_timestamp = interval_or_timestamp
      super("retry job in #{interval_or_timestamp}")
    end
  end

  extend Webhookdb::MethodUtilities

  def self.extended(cls)
    Webhookdb::Async.jobs << cls

    cls.include(Sidekiq::Worker)
    cls.extend(ClassMethods)
    cls.class_attribute :pattern
    cls.pattern = ""
    cls.include(InstanceMethods)
  end

  module InstanceMethods
    def initialize(*)
      super
      @change_matchers = {}
    end

    def logger
      return Webhookdb::Async::JobLogger.logger
    end

    def with_log_tags(tags, &)
      Webhookdb::Async::JobLogger.with_log_tags(tags, &)
    end

    def perform(*args)
      if args.empty?
        event = nil
      elsif args.size == 1
        event = Webhookdb::Event.from_json(args[0])
      else
        raise "perform should always be called with no args or [Webhookdb::Event#as_json], got %p" % [args]
      end
      begin
        self._perform(event)
      rescue Retry => e
        self.logger.info("scheduling_retry")
        self.class.perform_in(e.interval_or_timestamp)
      end
    end

    # Return +klass[payload_or_id]+ if it exists, or raise an error if it does not.
    # +payload_or_id+ can be an integer,
    # or the async job payload if the id is the first argument.
    #
    # Examples:
    # - `customer = self.lookup_model( Webhookdb::Customer, event )`
    # - `customer = self.lookup_model( Webhookdb::Customer, event.payload )`
    # - `customer = self.lookup_model( Webhookdb::Customer, customer_id )`
    def lookup_model(klass, payload_or_id)
      if payload_or_id.is_a?(Integer)
        id = payload_or_id
      elsif payload_or_id.respond_to?(:payload)
        id = payload_or_id.payload.first
      elsif payload_or_id.respond_to?(:first)
        id = payload_or_id.first
      else
        raise "Don't know how to handle #{payload_or_id}"
      end
      result = klass[id] or raise "%s[%p] does not exist" % [klass.name, id]
      return result
    end

    # Create a matcher against the 'changed' hash of an update event.
    #
    # Example:
    #    on 'webhookdb.customer.update' do |payload, _|
    #        customerid, changes, _ = *payload
    #        customer = Webhookdb::Customer[ customerid ] or return false
    #
    #        case changes
    #        when changed( :password )
    #            send_password_change_email( customer )
    #        when changed( :activation_code, to: nil )
    #            send_welcome_email( customer )
    #        when changed( :type, from: 'seeder', to: 'eater' )
    #            send_becoming_an_eater_email( customer )
    #        end
    #    end
    def changed(field, values={})
      unless @change_matchers[[field, values]]
        match_proc = self.make_match_proc_for(field, values)
        @change_matchers[[field, values]] = match_proc
      end

      return @change_matchers[[field, values]]
    end

    # Make a curried Proc for calling a match method with the given +field+ and +values+.
    def make_match_proc_for(field, values)
      return self.method(:match_any_change).to_proc.curry[field] if values.empty?

      if values.key?(:from)
        if values.key?(:to)
          return self.method(:match_change_from_to).to_proc.
              curry[ field, values[:from], values[:to] ]
        else
          return self.method(:match_change_from).to_proc.
              curry[ field, values[:from] ]
        end
      elsif values.key?(:to)
        return self.method(:match_change_to).to_proc.
            curry[ field, values[:to] ]
      else
        raise ScriptError,
              "Unhandled change option/s: %p; expected :to and/or :from" % [values.keys]
      end
    end

    # Returns +true+ if the given +field+ is listed at all in the specified
    # +changes+.
    def match_any_change(field, changes)
      self.logger.debug "Checking for existance of field %p in %p" % [field, changes]
      return changes&.key?(field.to_s)
    end

    # Returns +true+ if the given +field+ is listed in the specified +changes+,
    # and the value it changed to matches +to+. The +to+ value can be:
    #
    # a Regexp::
    #   The new value is stringified, and matched against the +to+ Regexp.
    # an immediate value (String, Numeric, NilClass, etc.)::
    #   The new value is matched using Object#==.
    #
    def match_change_to(field, to, changes)
      self.logger.debug "Checking for change to %p of field %p in %p" % [to, field, changes]
      return false unless changes&.key?(field.to_s)

      newval = changes[field.to_s][1]

      case to
        when NilClass, Numeric, String, TrueClass, FalseClass
          return newval == to
        when Regexp
          return to.match(newval)
        when Proc
          return to[newval]
        else
          raise TypeError, "Unhandled type of 'to' criteria %p (a %p)" % [to, to.class]
      end
    end

    # Returns +true+ if the given +field+ is listed in the specified +changes+,
    # and the value it changed from matches +from+. The +from+ value can be:
    #
    # a Regexp::
    #   The old value is stringified, and matched against the +from+ Regexp.
    # an immediate value (String, Numeric, NilClass, etc.)::
    #   The old value is matched using Object#==.
    #
    def match_change_from(field, from, changes)
      self.logger.debug "Checking for change from %p of field %p in %p" % [from, field, changes]
      return false unless changes&.key?(field.to_s)

      oldval = changes[field.to_s][0]

      case from
        when NilClass, Numeric, String, TrueClass, FalseClass
          return oldval == from
        when Regexp
          return from.match(oldval)
        when Proc
          return from[oldval]
        else
          raise TypeError, "Unhandled type of 'from' criteria %p (a %p)" % [from, from.class]
      end
    end

    # Returns +true+ if the given +field+ is listed in the specified +changes+,
    # and the value it changed from matches +from+ and the value it changed to
    # matches +to+. The +from+ and +to+ values can be:
    #
    # a Regexp::
    #   The corresponding value is stringified, and matched against the Regexp.
    # an immediate value (String, Numeric, NilClass, etc.)::
    #   The corresponding value is matched using Object#==.
    #
    def match_change_from_to(field, from, to, changes)
      self.logger.debug "Checking for change from %p to %p of field %p in %p" %
        [from, to, field, changes]
      return false unless changes&.key?(field.to_s)
      return self.match_change_to(field, to, changes) &&
          self.match_change_from(field, from, changes)
    end

    # Create a matcher against a changed Hash JSON column of an update event.
    #
    # Example:
    #    on 'webhookdb.customer.update' do |payload, _|
    #        customerid, changes, _ = *payload
    #
    #        case changes
    #        when changed_at( :flags, :trustworthy, to: true )
    #            mark_customer_safe_in_external_service( customerid )
    #        end
    #    end
    def changed_at(field, index, values={})
      return self.method(:match_change_at).to_proc.curry[field, index, values]
    end

    # Return +true+ if `field[index]` has changed in the specified +changes+,
    # configured by +values+ (contains +from+, +to+, or whatever supported kwargs).
    # Unlike other matches, +changes+ is expected to be an entire +Hash+
    # and may contain a value at +index+ in either or both sets of changes.
    # This method does not attempt to do the matching itself.
    # Rather, it sets up the data to defer to the other matcher methods.
    def match_change_at(field, index, values, changes)
      field = field.to_s
      return false unless changes&.key?(field)
      index = index.to_s
      old_values, new_values = changes[field]
      unrolled_changes = self.unroll_hash_changes(old_values, new_values)
      return self.changed(index, values)[unrolled_changes]
    end

    # Given two hashes that represent the before and after column hash values,
    # return a hash in the usual "changes" format,
    # where keys are the hash keys with changed values,
    # and values are a tuple of the before and after values.
    def unroll_hash_changes(old_hash, new_hash)
      old_hash ||= {}
      new_hash ||= {}
      return old_hash.keys.concat(new_hash.keys).uniq.each_with_object({}) do |key, h|
        old_val = old_hash[key]
        new_val = new_hash[key]
        h[key] = [old_val, new_val] if old_val != new_val
      end
    end
  end

  module ClassMethods
    def on(pattern)
      self.pattern = pattern
    end

    def scheduled_job?
      return false
    end

    def event_job?
      return true
    end
  end
end
