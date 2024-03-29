# frozen_string_literal: true

require "webhookdb"

module Webhookdb::Pry
  # Call this from .pryrc.
  #
  # @example
  # lib = File.expand_path("lib", __dir__)
  # $LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
  #
  # require "appydays/dotenviable"
  # Appydays::Dotenviable.load
  #
  # require "webhookdb/pry"
  # Webhookdb::Pry.setup(self)
  def self.setup(main)
    main.instance_exec do
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
        Webhookdb::Async.setup_web if Amigo.subscribers.empty?
        return
      end

      def copt
        rc = Appydays::Loggable[self].silence(:fatal) do
          Webhookdb::Customer::ResetCode.order(:id).last
        end
        tok = rc.token
        Clipboard.copy tok
        puts "Copied OTP #{tok} for #{rc.customer.email} to clipboard"
        return tok
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
        Amigo.register_subscriber do |ev|
          Webhookdb::Console.console_logger(ev)
        end
        return
      end
    end
  end
end
