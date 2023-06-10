# frozen_string_literal: true

require "webhookdb/db_adapter"

class Webhookdb::Replicator::Column
  include Webhookdb::DBAdapter::ColumnTypes

  class IsomorphicProc < Webhookdb::TypedStruct
    attr_reader :ruby, :sql
  end

  # Convert a Unix timestamp (fractional seconds) to a Datetime.
  CONV_UNIX_TS = IsomorphicProc.new(
    ruby: lambda do |i, **_|
      return Time.at(i)
    rescue TypeError
      return nil
    end,
    sql: lambda do |i|
      # We do not have the 'rescue TypeError' behavior here yet.
      # It is a beast to add in because we can't easily check if something is convertable,
      # nor can we easily exception handle without creating a stored function.
      Sequel.function(:to_timestamp, Sequel.cast(i, :double))
    end,
  )
  # Parse a value as an integer. Remove surrounding quotes.
  CONV_TO_I = IsomorphicProc.new(
    ruby: ->(i, **_) { i.nil? ? nil : i.delete_prefix('"').delete_suffix('"').to_i },
    sql: ->(i) { Sequel.cast(i, :integer) },
  )
  # Given a Datetime, convert it to UTC and truncate to a Date.
  CONV_TO_UTC_DATE = IsomorphicProc.new(
    ruby: ->(t, **_) { t&.in_time_zone("UTC")&.to_date },
    sql: lambda do |i|
      ts = Sequel.cast(i, :timestamptz)
      in_utc = Sequel.function(:timezone, "UTC", ts)
      Sequel.cast(in_utc, :date)
    end,
  )
  # Parse a value using Time.parse.
  CONV_PARSE_TIME = IsomorphicProc.new(
    ruby: ->(value, **_) { value.nil? ? nil : Time.parse(value) },
    sql: ->(i) { Sequel.cast(i, :timestamptz) },
  )

  # Parse a value using Date.parse.
  CONV_PARSE_DATE = IsomorphicProc.new(
    ruby: ->(value, **_) { value.nil? ? nil : Date.parse(value) },
    sql: ->(i) { Sequel.cast(i, :date) },
  )

  CONV_COMMA_SEP = IsomorphicProc.new(
    ruby: ->(value, **_) { value.nil? ? [] : value.split(",").map(&:strip) },
    sql: ->(*) { raise NotImplementedError },
  )

  # Return a converter that parses a value using the given regex,
  # and returns the capture group at index.
  # The 'coerce' function can be applied to, for example,
  # capture a number from a request path and store it as an integer.
  def self.converter_from_regex(re, coerce: nil, index: -1)
    return IsomorphicProc.new(
      ruby: lambda do |value, **_|
        matched = value&.match(re) do |md|
          md.captures ? md.captures[index] : nil
        end
        (matched = matched.send(coerce)) if !matched.nil? && coerce
        matched
      end,
      sql: ->(*) { raise "not yet supported" },
    )
  end

  def self.converter_int_or_sequence_from_regex(re, index: -1)
    return Webhookdb::Replicator::Column::IsomorphicProc.new(
      ruby: lambda do |value, service_integration:, **kw|
        url_id = Webhookdb::Replicator::Column.converter_from_regex(re, coerce: :to_i, index:).
          ruby.call(value, service_integration:, **kw)
        url_id || service_integration.sequence_nextval
      end,
      sql: ->(*) { raise NotImplementedError },
    )
  end

  def self.converter_strptime(format, cls: Time)
    return Webhookdb::Replicator::Column::IsomorphicProc.new(
      ruby: lambda do |value, **|
        value.nil? ? nil : cls.strptime(value, format)
      end,
      sql: ->(*) { raise NotImplementedError },
    )
  end

  def self.converter_gsub(pattern, replacement)
    return Webhookdb::Replicator::Column::IsomorphicProc.new(
      ruby: lambda do |value, **|
        value&.gsub(pattern, replacement)
      end,
      sql: ->(*) { raise NotImplementedError },
    )
  end

  def self.converter_array_element(index:, sep:, cls: DECIMAL)
    case cls
      when DECIMAL
        to_ruby = ->(v) { BigDecimal(v) }
        to_sql = ->(e) { Sequel.cast(e, :decimal) }
      else
        raise ArgumentError, "Unsupported cls" unless valid_cls.include?(cls)
    end

    return IsomorphicProc.new(
      ruby: lambda do |value, **|
        break nil if value.nil?
        parts = value.split(sep)
        break nil if index >= parts.size
        to_ruby.call(parts[index])
      end,
      sql: lambda do |expr|
        # The expression may be a JSONB field, of the type jsonb (accessed with -> rather than ->>).
        # Make sure it's text. The CAST will turn 'a' into '"a"' though, so we also need to trim quotes.
        str_expr = Sequel.cast(expr, :text)
        str_expr = Sequel.function(:btrim, str_expr, '"')
        field_expr = Sequel.function(:split_part, str_expr, sep, index + 1)
        # If the field is invalid, we get ''. Use nil in this case.
        case_expr = Sequel.case({Sequel[field_expr => ""] => nil}, field_expr)
        to_sql.call(case_expr)
      end,
    )
  end

  KNOWN_CONVERTERS = {
    date: CONV_PARSE_DATE,
    time: CONV_PARSE_TIME,
    to_i: CONV_TO_I,
    tsat: CONV_UNIX_TS,
  }.freeze

  DEFAULTER_NOW = IsomorphicProc.new(ruby: ->(*) { Time.now }, sql: ->(*) { Sequel.function(:now) })
  DEFAULTER_FALSE = IsomorphicProc.new(ruby: ->(*) { false }, sql: ->(*) { false })
  DEFAULTER_FROM_INTEGRATION_SEQUENCE = IsomorphicProc.new(
    ruby: ->(service_integration:, **_) { service_integration.sequence_nextval },
    sql: ->(service_integration:) { Sequel.function(:nextval, service_integration.sequence_name) },
  )

  def self.defaulter_from_resource_field(key)
    return Webhookdb::Replicator::Column::IsomorphicProc.new(
      ruby: ->(resource:, **_) { resource.fetch(key.to_s) },
      sql: ->(*) { key.to_sym },
    )
  end
  KNOWN_DEFAULTERS = {now: DEFAULTER_NOW, tofalse: DEFAULTER_FALSE}.freeze

  # @return [Symbol]
  attr_reader :name
  # @return [Symbol]
  attr_reader :type
  # @return [Boolean]
  attr_reader :index
  alias index? index

  # While :name, :type, and :index are pretty standard attributes for defining a database column,
  # the rest of these attributes are specialized to WebhookDB and deal with how we are finding
  # and interpreting the values given to us by external services.

  # `data_key` is the key we look for in the resource object. If this value is an array we will
  # `_dig` through the object using each key successively. `data_key` defaults to the string version
  # of whatever name you provide for the column.
  # @return [String,Array<String>]
  attr_reader :data_key

  # `event_key` is the key we look for in the event object. This defaults to nil, but note that if
  # both an event object and event key are provided, we will always grab the value from the event object
  # instead of from the resource object using the `data_key`. If this value is an array we will
  # `_dig` through the object using each key successively, same as with `data_key`.
  # @return [String,Array<String>]
  attr_reader :event_key

  # If `from_enrichment` is set then we use the `data_key` value to find the desired value in the
  # enrichment object. In this case, if the enrichment object is nil you will get an error.
  # @return [Boolean]
  attr_reader :from_enrichment

  # If `optional` is true then the column will be populated with a nil value instead of throwing an error
  # if the desired value is not present in the object you're `_dig`ging into, which could be any of the
  # three (resource, event, and enrichment) according to the way the rest of the attributes are configured.
  # Note that for nested values, `_dig` will return nil if *any* of the keys in the provided array are
  # missing from the object.
  # @return [Boolean]
  attr_reader :optional

  # Sometimes we need to do some processing on the value provided by the external service so that the we
  # get the data we want in the format we want. A common example is parsing various DateTime formats into our
  # desired timestamp format. In these cases, we use a `converter`, which is an `IsomorphicProc` where both
  # procs take the value retrieved from the external service and the resource object and return a value
  # consistent with the column's type attribute.
  #
  # @return [IsomorphicProc]
  #   The 'ruby' proc accepts (value, resource:, event:, enrichment:, service_integration:) and returns a value.
  #   The 'sql' proc takes an expression and returns a new expression.
  attr_reader :converter

  # If the value we retrieve from the data provided by the external service is nil, we often want to use
  # a default value instead of nil. The `defaulter` is an `IsomorphicProc` where both procs take the resource
  # object and return a default value that is used in the upsert. A common example is the `now` defaulter,
  # which uses the current time as the default value.
  #
  # @return [IsomorphicProc]
  #   The 'ruby' proc accepts (resource:, event:, enrichment:, service_integration:) and returns a value.
  #   The 'sql' proc accepts (service_integration:) and returns an sql expression.
  attr_reader :defaulter

  # If `skip_nil` is set to true, we only add the described value to the hash that gets upserted if it is not
  # nil. This is so that we don't override existing data in the database row with a nil value.
  # @return [Boolean]
  attr_reader :skip_nil
  alias skip_nil? skip_nil

  def initialize(
    name,
    type,
    data_key: nil,
    event_key: nil,
    from_enrichment: false,
    optional: false,
    converter: nil,
    defaulter: nil,
    index: false,
    skip_nil: false
  )
    raise ArgumentError, "name must be a symbol" unless name.is_a?(Symbol)
    raise ArgumentError, "type #{type.inspect} is not supported" unless COLUMN_TYPES.include?(type)
    raise ArgumentError, "use :tofalse as the defaulter (or nil for no defaulter)" if defaulter == false
    @name = name
    @type = type
    @data_key = data_key || name.to_s
    @event_key = event_key
    @from_enrichment = from_enrichment
    @optional = optional
    @converter = KNOWN_CONVERTERS[converter] || converter
    @defaulter = KNOWN_DEFAULTERS[defaulter] || defaulter
    @index = index
    @skip_nil = skip_nil
  end

  def to_dbadapter(**more)
    kw = {name: self.name, type: self.type, index: self.index}
    kw.merge!(more)
    return Webhookdb::DBAdapter::Column.new(**kw)
  end

  # Convert this column to an expression that can be used to return
  # the column's value based on what is present in the row.
  # This is generally used to 'backfill' column values
  # from what is in the data and enrichment columns.
  #
  # NOTE: this method assumes Postgres as the backing database.
  # To support others will require additional work and some abstraction.
  def to_sql_expr
    source_col = @from_enrichment ? :enrichment : :data
    expr = Sequel.pg_json(source_col)
    expr = case self.type
      when TIMESTAMP, DATE, TEXT
        expr.get_text(@data_key)
      else
        expr[Array(@data_key)]
    end
    (expr = self.converter.sql.call(expr)) if self.converter
    pgcol = Webhookdb::DBAdapter::PG::COLTYPE_MAP.fetch(self.type)
    expr = expr.cast(pgcol)
    (expr = Sequel.function(:coalesce, expr, self.defaulter.sql.call)) if self.defaulter
    return expr
  end

  def to_ruby_value(resource:, event:, enrichment:, service_integration:)
    v = if self.from_enrichment
          self._dig(enrichment, self.data_key, self.optional)
    elsif event && self.event_key
      # Event keys are never optional since any API using them is going to have fixed keys
      self._dig(event, self.event_key, false)
    else
      self._dig(resource, self.data_key, self.optional)
    end
    (v = self.defaulter.ruby.call(resource:, event:, enrichment:, service_integration:)) if self.defaulter && v.nil?
    v = self.converter.ruby.call(v, resource:, event:, enrichment:, service_integration:) if self.converter
    if (self.type == INTEGER_ARRAY) && !v.nil?
      v = Sequel.pg_array(v, "integer")
    elsif (self.type == TEXT_ARRAY) && !v.nil?
      v = Sequel.pg_array(v, "text")
    end
    # pg_json doesn't handle thie ssuper well in our situation,
    # so JSON must be inserted as a string.
    if (_stringify_json = self.type == OBJECT && !v.nil? && !v.is_a?(String))
      v = v.to_json
    end
    return v
  end

  def _dig(h, keys, optional)
    v = h
    karr = Array(keys)
    karr.each do |key|
      begin
        v = optional ? v[key] : v.fetch(key)
      rescue KeyError
        raise KeyError, "key not found: '#{key}' in: #{v.keys}"
      rescue NoMethodError => e
        raise NoMethodError, "Element #{key} of #{karr}\n#{e}"
      end
      # allow optional nested values by returning nil as soon as key not found
      # the problem here is that you effectively set all keys in the sequence as optional
      break if optional && v.nil?
    end
    return v
  end
end
