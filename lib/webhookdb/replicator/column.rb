# frozen_string_literal: true

require "webhookdb/db_adapter"

class Webhookdb::Replicator::Column
  include Webhookdb::DBAdapter::ColumnTypes

  class IsomorphicProc < Webhookdb::TypedStruct
    attr_reader :ruby, :sql
  end

  NOT_IMPLEMENTED = ->(*) { raise NotImplementedError }

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
    sql: lambda do |_e, json_path:, source_col:|
      e = source_col.get_text(json_path)
      parts = Sequel.function(:string_to_array, e, ",")
      parts = Sequel.function(:unnest, parts)
      sel = Webhookdb::Dbutil::MOCK_CONN.
        from(parts.as(:parts)).
        select(Sequel.function(:trim, :parts))
      f = Sequel.function(:array, sel)
      return f
    end,
  )

  # Return a converter that parses a value using the given regex,
  # and returns the capture group at index.
  # The 'coerce' function can be applied to, for example,
  # capture a number from a request path and store it as an integer.
  #
  # @param pattern [String]
  # @param dbtype [Symbol] The DB type to use, like INTEGER or BIGINT.
  #
  # @note Only the first capture group can be extracted at this time.
  def self.converter_from_regex(pattern, dbtype: nil)
    re = self._assert_regex_converter_type(pattern)
    case dbtype
      when INTEGER
        rcoerce = :to_i
        pgcast = :integer
      when BIGINT
        rcoerce = :to_i
        pgcast = :bigint
      when nil
        rcoerce = nil
        pgcast = nil
      else
        raise NotImplementedError, "unhandled converter_from_regex dbtype: #{dbtype}"
    end
    return IsomorphicProc.new(
      ruby: lambda do |value, **_|
        matched = value&.match(re) do |md|
          md.captures ? md.captures[0] : nil
        end
        (matched = matched.send(rcoerce)) if !matched.nil? && rcoerce
        matched
      end,
      sql: lambda do |e|
        f = Sequel.function(:substring, e.cast(:text), pattern)
        f = f.cast(pgcast) if pgcast
        f
      end,
    )
  end

  # Extract a number from a string using the given regexp.
  # If nothing can be extracted, get the next value from the sequence.
  #
  # Note this requires `requires_sequence=true` on the replicator.
  #
  # Used primarily where the ID is sent by an API only in the request URL (not a key in the body),
  # and the URL will not include an ID when it's being sent for the first time.
  # We see this in channel manager APIs primarily, that replicate their data to 3rd parties.
  #
  # @note This converter does not work for backfilling/UPDATE of existing columns.
  # It is generally only of use for unique ids.
  def self.converter_int_or_sequence_from_regex(re, dbtype: BIGINT)
    return Webhookdb::Replicator::Column::IsomorphicProc.new(
      ruby: lambda do |value, service_integration:, **kw|
        url_id = Webhookdb::Replicator::Column.converter_from_regex(re, dbtype:).
          ruby.call(value, service_integration:, **kw)
        url_id || service_integration.sequence_nextval
      end,
      sql: NOT_IMPLEMENTED,
    )
  end

  # Parse the value in the column using the given strptime string.
  #
  # To provide an `sql` proc, provide the sqlformat string, which is used in TO_TIMESTAMP(col, sqlformat).
  # Note that TO_TIMESTAMP does not support timezone offsets,
  # so the time will always be in UTC.
  #
  # Future note: We may want to derive sqlformat from format,
  # and handle timezone offsets in the timestamp strings.
  def self.converter_strptime(format, sqlformat=nil, cls: Time)
    return Webhookdb::Replicator::Column::IsomorphicProc.new(
      ruby: lambda do |value, **|
        value.nil? ? nil : cls.strptime(value, format)
      end,
      sql: lambda do |e|
        raise NotImplementedError if sqlformat.nil?
        f = Sequel.function(:to_timestamp, e, sqlformat)
        f = f.cast(:date) if cls == Date
        f
      end,
    )
  end

  def self.converter_gsub(pattern, replacement)
    re = self._assert_regex_converter_type(pattern)
    return Webhookdb::Replicator::Column::IsomorphicProc.new(
      ruby: lambda do |value, **|
        value&.gsub(re, replacement)
      end,
      sql: lambda do |e|
        Sequel.function(:regexp_replace, e, pattern, replacement, "g")
      end,
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

  def self.converter_array_pluck(key, coltype)
    pgtype = Webhookdb::DBAdapter::PG::COLTYPE_MAP.fetch(coltype)
    return IsomorphicProc.new(
      ruby: lambda do |value, **|
        break nil if value.nil?
        break nil unless value.respond_to?(:to_ary)
        value.map { |v| v[key] }
      end,
      sql: lambda do |expr|
        expr = Sequel.lit("'#{JSON.generate(expr)}'::jsonb") if expr.is_a?(Hash) || expr.is_a?(Array)
        Webhookdb::Dbutil::MOCK_CONN.
          from(Sequel.function(:jsonb_to_recordset, expr).as(Sequel.lit("x(#{key} #{pgtype})"))).
          select(Sequel.function(:array_agg, Sequel.lit(key)))
      end,
    )
  end

  DAYS_OF_WEEK = [
    "SUNDAY",
    "MONDAY",
    "TUESDAY",
    "WEDNESDAY",
    "THURSDAY",
    "FRIDAY",
    "SATURDAY",
  ].freeze

  # Convert a value or array by looking up its value in a map.
  # @param array [Boolean] If true, the empty value is an array. If false, nil.
  # @param map [Hash]
  def self.converter_map_lookup(array:, map:)
    empty = array ? Sequel.pg_array([]) : nil
    return IsomorphicProc.new(
      ruby: lambda do |value, **|
        break empty if value.nil?
        is_ary = value.respond_to?(:to_ary)
        r = (is_ary ? value : [value]).map do |v|
          if (mapval = map[v])
            mapval
          else
            v
          end
        end
        break is_ary ? r : r[0]
      end,
      sql: NOT_IMPLEMENTED,
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

  # Use in data_key when a value is an array, and you want to map a value from the array.
  EACH_ITEM = :_each_item

  # @return [Symbol]
  attr_reader :name
  # @return [Symbol]
  attr_reader :type
  # @return [Boolean]
  attr_reader :index
  alias index? index

  # True if thie index should be a partial index, using WHERE (col IS NOT NULL).
  # The #index attribute must be true.
  # @return [Boolean]
  attr_reader :index_not_null

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

  # If provided, run this before backfilling as part of UPDATE.
  # Usually used to add functions into pg_temp schema.
  # This is an advanced use case; see unit tests for examples.
  attr_reader :backfill_statement

  # If provided, use this expression as the UPDATE value when adding the column
  # to an existing table.
  # @return [String,Sequel,Sequel::SQL::Expression]
  attr_reader :backfill_expr

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
    index_not_null: false,
    skip_nil: false,
    backfill_statement: nil,
    backfill_expr: nil
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
    @index_not_null = index_not_null
    @skip_nil = skip_nil
    @backfill_statement = backfill_statement
    @backfill_expr = backfill_expr
  end

  def to_dbadapter(**more)
    kw = {name:, type:, index:, backfill_expr:, backfill_statement:}
    kw[:index_where] = Sequel[self.name] !~ nil if self.index_not_null
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
    source_col_expr = Sequel.pg_json(source_col)
    # Have to use string keys here, PG handles it alright though.
    dkey = @data_key.respond_to?(:to_ary) ? @data_key.map(&:to_s) : @data_key
    expr = case self.type
      # If we're pulling out a normal value from JSON, get it as a 'native' value (not jsonb) (ie, ->> op).
      when TIMESTAMP, DATE, TEXT, INTEGER, BIGINT
        source_col_expr.get_text(dkey)
      else
        # If this is a more complex value, get it as jsonb (ie, -> op).
        # Note that this can be changed by the sql converter.
        source_col_expr[Array(dkey)]
    end
    if self.converter
      if self.converter.sql == NOT_IMPLEMENTED
        msg = "Converter SQL for #{self.name} is not implemented. This column cannot be added after the fact, " \
              "backfill_expr should be set on the column to provide a manual UPDATE/backfill converter, " \
              "or the :sql converter can be implemented (may not be possible or feasible in all cases)."
        raise TypeError, msg
      end
      conv_kwargs = self.converter.sql.arity == 1 ? {} : {json_path: dkey, source_col: source_col_expr}
      expr = self.converter.sql.call(expr, **conv_kwargs)
    end
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
    elsif (self.type == BIGINT_ARRAY) && !v.nil?
      v = Sequel.pg_array(v, "bigint")
    elsif (self.type == TIMESTAMP) && !v.nil?
      # Postgres CANNOT handle timestamps with a 0000 year,
      # even if the actual time it represents is valid (due to timezone offset).
      # Repro with `SELECT '0000-12-31T18:10:00-05:50'::timestamptz`.
      # So if we are in the year 0, represent the time into UTC to get it out of year 0
      # (if it's still invalid, let it error).
      # NOTE: Only worry about times; if the value is a string, it will still error.
      # Let the caller parse the string into a Time to get this special behavior.
      # Time parsing is too loose to do it here.
      v = v.utc if v.is_a?(Time) && v.year.zero?
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

  def self._assert_regex_converter_type(re)
    return Regexp.new(re) if re.is_a?(String)
    raise ArgumentError, "regexp must be a string, not a Ruby regex, so it can be used in the database verbatim"
  end
end
