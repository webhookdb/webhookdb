# frozen_string_literal: true

lib = File.expand_path("lib", __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

require "appydays/dotenviable"
Appydays::Dotenviable.load

require "webhookdb"
require "pry/clipboard"

Pry.config.commands.alias_command "ch", "copy-history"
Pry.config.commands.alias_command "cr", "copy-result"

# Decode the given cookie string. Since cookies are encrypted,
# this is useful for debugging what they contain.
def decode_cookie(s)
  require "webhookdb/service"
  return Webhookdb::Service.decode_cookie(s)
end

# Connect this session of Pry to the database.
# It also registers subscribers, so changes to the models are handled
# by their correct async jobs (since async jobs are handled in-process).
def connect
  require "webhookdb"
  Webhookdb.load_app

  return unless require "webhookdb/async"
  Webhookdb::Async.register_subscriber
  return
end

# Load models and fixtures. Use this when riffing locally.
def repl
  require "webhookdb"
  Webhookdb.load_app
  require "webhookdb/fixtures"
  Webhookdb::Fixtures.load_all
  return
end

def console
  connect
  require "webhookdb/console"
  Webhookdb::Console.enable_safe_mode
  self.extend Webhookdb::Console::MainMethods
  Webhookdb.register_subscriber do |ev|
    Webhookdb::Console.console_logger(ev)
  end
  return
end
