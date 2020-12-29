# frozen_string_literal: true

require "semantic_logger"

require "appydays/version"

##
# Override SemanticLogger's keys for tags, named_tags, and payload.
# It is emminently unhelpful to have three places the same data may be-
# ie, in some cases, we may have a customer_id in a named tag,
# sometimes in payload, etc. Callsite behavior should not vary
# the shape/content of the log message.
class SemanticLogger::Formatters::Raw
  alias original_call call

  def call(log, logger)
    h = self.original_call(log, logger)
    ctx = h[:context] ||= {}
    ctx[:_tags] = h.delete(:tags) if h.key?(:tags)

    [:named_tags, :payload].each do |hash_key|
      next unless h.key?(hash_key)
      h.delete(hash_key).each do |k, v|
        ctx[k] = v
      end
    end

    return h
  end
end

##
# Helpers for working with structured logging.
# Use this instead of calling semantic_logger directly.
# Generally you `include Appydays::Loggable`
module Appydays::Loggable
  def self.included(target)
    target.include(SemanticLogger::Loggable)

    target.extend(Methods)
    target.include(Methods)
  end

  def self.default_level=(v)
    self.set_default_level(v)
  end

  def self.set_default_level(v, warning: true)
    return if v == SemanticLogger.default_level
    self[self].warn "Overriding log level to %p" % v if warning
    SemanticLogger.default_level = v
  end

  ##
  # Return the logger for a key/object.
  def self.[](key)
    return key.logger if key.respond_to?(:logger)
    (key = key.class) unless [Module, Class].include?(key.class)
    return SemanticLogger[key]
  end

  ##
  # Configure logging for 12 factor applications.
  # Specifically, that means setting STDOUT to synchronous,
  # using STDOUT as the log output,
  # and also conveniently using color formatting if using a tty or json otherwise
  # (ie, you want to use json logging on a server).
  def self.configure_12factor(format: nil, application: nil)
    format ||= $stdout.isatty ? :color : :json
    $stdout.sync = true
    SemanticLogger.application = application if application
    SemanticLogger.add_appender(io: $stdout, formatter: format.to_sym)
  end

  def self.with_log_tags(tags, &block)
    return SemanticLogger.named_tagged(tags, &block)
  end

  @stderr_appended = false

  def self.ensure_stderr_appender
    return if @stderr_appended
    SemanticLogger.add_appender(io: $stderr)
    @stderr_appended = true
  end

  module Methods
    def with_log_tags(tags, &block)
      return SemanticLogger.named_tagged(tags, &block)
    end
  end
end
