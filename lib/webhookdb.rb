# frozen_string_literal: true

require "active_support"
require "active_support/core_ext"
require "appydays/configurable"
require "appydays/loggable"
require "money"
require "pathname"
require "phony"

require "webhookdb/json"

if (heroku_app = ENV.fetch("MERGE_HEROKU_ENV", nil))
  text = `heroku config -j --app=#{heroku_app}`
  json = Oj.load(text)
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
  class InvalidPrecondition < StandardError; end

  # Error raised when, after we take an action,
  # something we expect to have changed has not changed.
  class InvalidPostcondition < StandardError; end

  # Some invariant has been violated, which we never expect to see.
  class InvariantViolation < StandardError; end

  # Error raised when a customer gives us some invalid input.
  # Allows the library to raise the error with the message,
  # and is caught automatically by the service as a 400.
  class InvalidInput < StandardError; end

  # Raised when an organization's database cannot be modified.
  class DatabaseLocked < StandardError; end

  # Used in various places that need to short-circuit code in regression mode.
  class RegressionModeSkip < StandardError; end

  APPLICATION_NAME = "Webhookdb"
  RACK_ENV = ENV.fetch("RACK_ENV", "development")
  COMMIT = ENV.fetch("HEROKU_SLUG_COMMIT", "unknown-commit")
  RELEASE = ENV.fetch("HEROKU_RELEASE_VERSION", "unknown-release")
  RELEASE_CREATED_AT = ENV.fetch("HEROKU_RELEASE_CREATED_AT") { Time.at(0).utc.iso8601 }
  INTEGRATION_TESTS_ENABLED = ENV.fetch("INTEGRATION_TESTS", false)

  DATA_DIR = Pathname(__FILE__).dirname.parent + "data"

  configurable(:webhookdb) do
    setting :log_level_override,
            nil,
            key: "LOG_LEVEL",
            side_effect: ->(v) { Appydays::Loggable.default_level = v if v }
    setting :log_format, nil
    setting :app_url, "http://localhost:18002"
    setting :api_url, "http://localhost:#{ENV.fetch('PORT', 18_001)}"
    setting :bust_idempotency, false
    setting :http_user_agent, ""
    setting :oss_repo_url, "https://github.com/webhookdb/webhookdb"
    setting :support_email, "hello@webhookdb.com"
    setting :use_globals_cache, false
    setting :regression_mode, false
  end

  # Regression mode is true when we re replaying webhooks locally,
  # or for some other reason, want to disable certain checks we use in production.
  # For example, we may want to ignore certain errors (like if integrations are missing dependency rows),
  # or disable certain validations (like always assume the webhook is valid).
  def self.regression_mode?
    return self.regression_mode
  end

  require "webhookdb/method_utilities"
  extend Webhookdb::MethodUtilities

  require "webhookdb/sentry"

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

  # Convert a string into something we consistently use for slugs:
  # a-z, 0-9, and underscores only. Leading numbers are converted to words.
  #
  # Acme + Corporation -> "acme_corporation"
  # 1Byte -> "one_byte"
  # 10Byte -> "one0_byte"
  def self.to_slug(s)
    raise ArgumentError, "s cannot be nil" if s.nil?
    return "" if s.blank?
    slug = s.downcase.strip.gsub(/[^a-z0-9]/, "_").squeeze("_")
    slug = NUMBERS_TO_WORDS[slug.first] + slug[1..] if slug.first.match?(/[0-9]/)
    return slug
  end

  NUMBERS_TO_WORDS = {
    "0" => "zero",
    "1" => "one",
    "2" => "two",
    "3" => "three",
    "4" => "four",
    "5" => "five",
    "6" => "six",
    "7" => "seven",
    "8" => "eight",
    "9" => "nine",
  }.freeze

  # Return the request user and admin stored in TLS. See service.rb for implementation.
  #
  # Note that the second return value (the admin) will be nil if not authed as an admin,
  # and if an admin is impersonating, the impersonated customer is the first value.
  #
  # Both values will be nil if no user is authed or this is called outside of a request.
  #
  # Usually these fields should only be used where it would be sufficiently difficult
  # to pass the current user through the stack.
  # In the API, you should instead use the 'current customer' methods
  # like current_customer, and admin_customer, NOT using TLS.
  # Outside of the API, this should only be used for things like auditing;
  # it should NOT, for example, ever be used to determine the 'customer owner' of objects
  # being created. Nearly all code will be simpler if the current customer
  # is passed around. But it would be too complex for some code (like auditing)
  # so this system exists. Overuse of request_user_and_admin will inevitably lead to regret.
  def self.request_user_and_admin
    return Thread.current[:request_user], Thread.current[:request_admin]
  end

  # Return the request user stored in TLS. See service.rb for details.
  def self.set_request_user_and_admin(user, admin, &block)
    if !user.nil? && !admin.nil? && self.request_user_and_admin != [nil, nil]
      raise Webhookdb::InvalidPrecondition, "request user is already set: #{user}, #{admin}"
    end
    Thread.current[:request_user] = user
    Thread.current[:request_admin] = admin
    return if block.nil?
    begin
      yield
    ensure
      Thread.current[:request_user] = nil
      Thread.current[:request_admin] = nil
    end
  end
end

require "webhookdb/aggregate_result"
require "webhookdb/dbutil"
require "webhookdb/developer_alert"
require "webhookdb/http"
require "webhookdb/phone_number"
require "webhookdb/replicator"
require "webhookdb/typed_struct"
require "webhookdb/webhook_response"
