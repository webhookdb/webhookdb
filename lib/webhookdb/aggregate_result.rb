# frozen_string_literal: true

require "webhookdb" unless defined?(Webhookdb)

# Value returned or raised from a method that deals with aggregate success or failure.
#
# Sometimes we want to process a collection of items,
# and not fail the entire thing if some fail. In this case, we can return an AggregateResult.
# If the AggregateResult is returned, we know all items processed.
# If it is raised, at least some of the items errored.
#
# Example:
#   ag = AggregateResult.new
#   items.each do |item|
#     ag.success(myfunc(item))
#   rescue => e
#     ag.failure(item, e)
#   end
#   return ag.finish
#
class Webhookdb::AggregateResult < RuntimeError
  attr_reader :successes, :failures, :errors

  def initialize(existing=nil)
    if existing.nil?
      @successes = []
      @failures = []
      @errors = []
      super("awaiting result")
      return
    end
    # We can only set the exception message from initialization
    @successes = existing.successes
    @failures = existing.failures
    @errors = existing.errors
    if @failures.empty?
      super("No errors")
      return
    end

    lines = ["Multiple errors occurred:"]
    @failures.each_with_index do |f, i|
      lines << " #{f.inspect}: #{@errors[i].message}"
    end
    super(lines.join("\n"))
  end

  def success(i)
    @successes << i
  end

  def failure(i, e)
    @failures << i
    @errors << e
  end

  def finish
    raise InvalidPrecondition, "failures.length must equal errors.length" unless @failures.length == @errors.length
    result = Webhookdb::AggregateResult.new(self)
    return result if self.failures.empty?
    raise result
  end
end
