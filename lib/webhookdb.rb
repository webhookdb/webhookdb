# frozen_string_literal: true

require "active_support"
require "active_support/core_ext"
require "appydays/configurable"
require "appydays/loggable"
require "money"
require "pathname"
require "phony"
require "yajl"

if (heroku_app = ENV["MERGE_HEROKU_ENV"])
  text = `heroku config -j --app=#{heroku_app}`
  json = Yajl::Parser.parse(text)
  json.each do |k, v|
    ENV[k] = v
  end
end

Money.locale_backend = :i18n
Money.default_currency = "USD"
Money.rounding_mode = BigDecimal::ROUND_HALF_UP

module Webhookdb
  include Appydays::Loggable
  include Appydays::Configurable

  # Error raised when we cannot take an action
  # because some condition has not been set up right.
  class InvalidPrecondition < RuntimeError; end

  # Error raised when, after we take an action,
  # something we expect to have changed has not changed.
  class InvalidPostcondition < RuntimeError; end

  APPLICATION_NAME = "Webhookdb"
  RACK_ENV = ENV["RACK_ENV"] || "development"
  VERSION = ENV["HEROKU_SLUG_COMMIT"] || "unknown-version"
  RELEASE = ENV["HEROKU_RELEASE_VERSION"] || "unknown-release"
  INTEGRATION_TESTS_ENABLED = ENV["INTEGRATION_TESTS"] || false

  DATA_DIR = Pathname(__FILE__).dirname.parent + "data"

  configurable(:webhookdb) do
    setting :log_level_override,
            nil,
            key: "LOG_LEVEL",
            side_effect: ->(v) { Appydays::Loggable.default_level = v if v }
    setting :log_format, nil
    setting :app_url, "http://localhost:18002"
    setting :api_url, "http://localhost:#{ENV['PORT'] || 17_001}"
    setting :bust_idempotency, false
    setting :marketing_site, "https://webhookdb.com/"
    setting :use_globals_cache, false
  end

  require "webhookdb/method_utilities"
  extend Webhookdb::MethodUtilities

  require "webhookdb/raven"

  def self.load_app
    $stdout.sync = true
    $stderr.sync = true

    Appydays::Loggable.configure_12factor(format: self.log_format, application: APPLICATION_NAME)

    require "webhookdb/postgres"
    Webhookdb::Postgres.load_models
  end

  #
  # :section: Globals cache
  #

  singleton_attr_reader :globals_cache
  @globals_cache = {}

  # If globals caching is enabled, see if there is a cached value under +key+
  # and return it if so. If there is not, evaluate the given block and store that value.
  # Generally used for looking up well-known database objects like certain roles.
  def self.cached_get(key)
    if self.use_globals_cache
      result = self.globals_cache[key]
      return result if result
    end
    result = yield()
    self.globals_cache[key] = result
    return result
  end

  #
  # :section: Errors
  #

  class LockFailed < StandardError; end

  ### Generate a key for the specified Sequel model +instance+ and
  ### any additional +parts+ that can be used for idempotent requests.
  def self.idempotency_key(instance, *parts)
    key = "%s-%s" % [instance.class.implicit_table_name, instance.pk]

    if instance.respond_to?(:updated_at) && instance.updated_at
      parts << instance.updated_at
    elsif instance.respond_to?(:created_at) && instance.created_at
      parts << instance.created_at
    end
    parts << SecureRandom.hex(8) if self.bust_idempotency
    key << "-" << parts.map(&:to_s).join("-") unless parts.empty?

    return key
  end

  #
  # :section: Unambiguous/promo code chars
  #

  # Remove ambiguous characters (L, I, 1 or 0, O) and vowels from possible codes
  # to avoid creating ambiguous codes or real words.
  UNAMBIGUOUS_CHARS = "CDFGHJKMNPQRTVWXYZ23469".chars.freeze

  def self.take_unambiguous_chars(n)
    return Array.new(n) { UNAMBIGUOUS_CHARS.sample }.join
  end

  #
  # :section: Event API
  #

  class Event
    def self.from_json(o)
      return self.new(o["id"], o["name"], o["payload"])
    end

    attr_reader :id, :name, :payload

    def initialize(id, name, payload)
      @id = id
      @name = name
      @payload = payload.map { |p| self.safe_stringify(p) }
    end

    def inspect
      return "#<%p:%#0x [%s] %s %p>" % [
        self.class,
        self.object_id * 2,
        self.id,
        self.name,
        self.payload,
      ]
    end

    def as_json(_opts={})
      return {
        "id" => self.id,
        "name" => self.name,
        "payload" => self.payload,
      }
    end

    protected def safe_stringify(o)
      return o.respond_to?(:deep_stringify_keys) ? o.deep_stringify_keys : o
    end
  end

  # An Array of callbacks to be run when an event is published.
  singleton_attr_reader :subscribers
  @subscribers = Set.new

  # A single callback to be run when an event publication errors.
  singleton_attr_accessor :on_publish_error
  @on_publish_error = proc {}

  # Publish an event with the specified +eventname+ and +payload+
  # to any configured publishers.
  def self.publish(eventname, *payload)
    ev = Event.new(SecureRandom.uuid, eventname, payload)

    self.subscribers.to_a.each do |hook|
      hook.call(ev)
    rescue StandardError => e
      self.logger.error "%p when calling event publication hook %p with %p: %s" %
        [e.class, hook, ev, e.message]
      self.logger.debug { e.backtrace.join("\n") }
      self.on_publish_error.call(e)
    end
  end

  ### Register a hook to be called when an event is sent.
  def self.register_subscriber(&block)
    raise LocalJumpError, "no block given" unless block
    self.logger.info "Setting up event publication hook: %p" % [block]
    self.subscribers << block
    return block
  end

  def self.unregister_subscriber(block_ref)
    self.subscribers.delete(block_ref)
  end

  # Convert a string into something we consistently use for slugs:
  # a-z, 0-9, and underscores only.
  # Acme + Corporation -> acme_corporation
  def self.to_slug(s)
    return s.downcase.gsub(/[^a-z0-9]/, "_").squeeze("_")
  end
end

require "webhookdb/aggregate_result"
require "webhookdb/phone_number"
require "webhookdb/services"
