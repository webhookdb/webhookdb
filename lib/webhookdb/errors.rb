# frozen_string_literal: true

module Webhookdb::Errors
  class << self
    # Call the given block for the given exception, each cause (see +Exception#cause+),
    # and each wrapped errors (see +Amigo::Retry::Error#wrapped+).
    # If the block returns +true+ for any exception, stop walking.
    def each_cause(ex, &)
      raise LocalJumpError unless block_given?
      return true if yield(ex) == true
      caused_got = ex.cause && each_cause(ex.cause, &)
      return true if caused_got == true
      wrapped_got = ex.respond_to?(:wrapped) && ex.wrapped && each_cause(ex.wrapped, &)
      return true if wrapped_got == true
      return nil
    end

    # Run the given block for each cause (see +each_cause),
    # returning the first exception the block returns +true+ for.
    def find_cause(ex, &)
      raise LocalJumpError unless block_given?
      got = nil
      each_cause(ex) do |cause|
        if yield(cause) == true
          got = cause
          true
        else
          false
        end
      end
      return got
    end
  end
end
