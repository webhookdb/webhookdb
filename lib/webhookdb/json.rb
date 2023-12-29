# frozen_string_literal: true

require "json"
require "oj"
require "active_support/json"

module Webhookdb
  # Helpers for JSON encoding and (to a lesser degree) decoding.
  # In general, decoding JSON in Ruby is simple, as long as we
  # don't try and deal with automatically converting types (which we don't).
  #
  # But encoding JSON is complex, like for example encoding a Time.
  # ActiveSupport uses #as_json to convert Ruby types to JSON-native types.
  # In order to use this, we must call Webhookdb::Json.encode,
  # or go through ActiveSupport (which we patch here).
  #
  # That is, using JSON.dump(Time.now) would give you '"1970-01-01 02:00:00 +0200"'
  # but using Webhookdb::Json.encode(Time.now) gives you '"1970-01-01T02:00:00.123+02:00"'
  #
  # Anyway, this is all largely under the hood and handled for us using ActiveSupport,
  # but while we switched Yajl to Oj, we went ahead and added this shim to bypass
  # the worst part of ActiveSupport (its still very tied to Rails needs).
  module Json
    DEFAULT_OPTIONS = {}.freeze
    PRETTY_OPTIONS = {indent: "  ", space: " ", object_nl: "\n", array_nl: "\n"}.freeze

    # Based on ActiveSupport::JSON::Encoding::JSONGemEncoder.
    # Removes the HTML escaping code (which is slow), but otherwise continues to depend
    # on the as_json approach.
    class Encoder
      attr_reader :options

      def initialize(options=nil)
        @options = options || DEFAULT_OPTIONS
      end

      def encode(value)
        return stringify(jsonify(value.as_json(@options.dup)))
      end

      # Convert an object into a "JSON-ready" representation composed of
      # primitives like Hash, Array, String, Numeric,
      # and +true+/+false+/+nil+.
      # Recursively calls #as_json to the object to recursively build a
      # fully JSON-ready object.
      #
      # This allows developers to implement #as_json without having to
      # worry about what base types of objects they are allowed to return
      # or having to remember to call #as_json recursively.
      #
      # Note: the +options+ hash passed to +object.to_json+ is only passed
      # to +object.as_json+, not any of this method's recursive +#as_json+
      # calls.
      def jsonify(value)
        case value
          when Rational
            value.to_s
          when String, Numeric, NilClass, TrueClass, FalseClass
            value.as_json
          when Hash
            result = {}
            value.each do |k, v|
              result[jsonify(k)] = jsonify(v)
            end
            result
          when Array
            value.map { |v| jsonify(v) }
          else
            jsonify value.as_json
        end
      end

      def stringify(jsonified)
        # If this breaks because we actually need to handle more types,
        # add them to jsonify, like Rational.
        #
        # We can't use `mode: :rails` here since we can't control
        # whether to use html-escaping (we don't want to use it) without using `Oj.optimize_rails`,
        # which causes other problems- we want to use ISO8601 encoding with millsecond precision,
        # but we get JSON-gem-style formatting (even if setting flags to modify ActiveSupport params)
        # when we use `optimize-rails` (but not mode: :rails, since we stringify the time beforehand).
        return ::Oj.dump(jsonified, mode: :strict, **@options)
      end
    end

    class << self
      # Dump as compact, standard JSON, using iso8601 for times.
      def encode(value, options=nil)
        Encoder.new(options).encode(value)
      end

      # Dump as pretty JSON, similar to JSON.pretty_generate but with iso8601 times.
      def pretty_generate(value)
        Webhookdb::Json.encode(value, PRETTY_OPTIONS)
      end
    end
  end
end

# This stomps the JSON.load, etc., methods, to use the faster (and still compatible) Oj version.
Oj.mimic_JSON

# Use the shim encoder rather than the ActiveSupport one.
# This mostly handles #to_json calls.
ActiveSupport::JSON::Encoding.json_encoder = Webhookdb::Json::Encoder

# Replace ActiveSupport::JSON.encode so it calls Oj directly.
# This isn't strictly necessary (since we set json_encoder), but skips an extra method call.
module ActiveSupport::JSON
  def self.encode(value, options=nil)
    return Webhookdb::Json.encode(value, options)
  end
end
