# frozen_string_literal: true

# Patch Sequel::Database logging methods for structured logging
require "sequel/database/logging"

class Sequel::Database
  def log_exception(exception, message)
    log_each(
      :error,
      proc { "#{exception.class}: #{exception.message.strip if exception.message}: #{message}" },
      proc { ["sequel_exception", {sequel_message: message}, exception] },
    )
  end

  # Log a message at level info to all loggers.
  def log_info(message, args=nil)
    log_each(
      :info,
      proc { args ? "#{message}; #{args.inspect}" : message },
      proc { ["sequel_log", {message: message, args: args}] },
    )
  end

  # Log message with message prefixed by duration at info level, or
  # warn level if duration is greater than log_warn_duration.
  def log_duration(duration, message)
    lwd = log_warn_duration
    log_each(
      lwd && (duration >= lwd) ? :warn : sql_log_level,
      proc { "(#{'%0.6fs' % duration}) #{message}" },
      proc { ["sequel_query", {duration: duration, query: message}] },
    )
  end

  def log_each(level, std, semantic)
    @loggers.each do |logger|
      if logger.is_a?(SemanticLogger::Base)
        logger.public_send(level, *semantic.call)
      else
        logger.public_send(level, std.call)
      end
    end
  end
end
