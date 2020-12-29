# frozen_string_literal: true

require "appydays/loggable"

module Appydays::Loggable::SpecHelpers
  def self.included(context)
    # Appydays::Loggable.ensure_stderr_appender

    context.around(:each) do |example|
      override_level = (example.metadata[:log] || example.metadata[:logging])
      if override_level
        orig_level = SemanticLogger.default_level
        SemanticLogger.default_level = override_level
      end
      example.run
      SemanticLogger.default_level = orig_level if override_level
    end

    context.before(:all) do
      Appydays::Loggable.set_default_level(:fatal, warning: false)
    end

    context.after(:all) do
      Appydays::Loggable.set_default_level(:fatal, warning: false)
    end

    super
  end

  def capture_logs_from(loggers, level: "debug", formatter: nil)
    (loggers = [loggers]) unless loggers.respond_to?(:to_ary)

    existing_appenders_and_lvls = SemanticLogger.appenders.map { |app| [app, app.level] }
    SemanticLogger.appenders.each { |app| app.level = :fatal }
    original_levels_and_loggers = loggers.map { |log| [log, log.level] }
    loggers.each { |log| log.level = level }

    io = StringIO.new
    appender = SemanticLogger.add_appender(io: io, level: level)
    appender.formatter = formatter if formatter
    begin
      yield
    ensure
      SemanticLogger.flush
      SemanticLogger.remove_appender(appender)
      original_levels_and_loggers.each { |(log, lvl)| log.level = lvl }
      existing_appenders_and_lvls.each { |(app, lvl)| app.level = lvl }
    end
    return io.string.lines
  end
end
