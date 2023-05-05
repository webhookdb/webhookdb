# frozen_string_literal: true

require "support/shared_examples_for_columns"

RSpec.describe Webhookdb::Replicator::Column, :db do
  let(:identity_conv) do
    described_class::IsomorphicProc.new(ruby: ->(v, *) { v }, sql: proc { raise NotImplementedError })
  end

  describe "to_ruby_value" do
    def to_ruby_value(col, resource=nil, event=nil, enrichment=nil, service_integration=nil)
      col.to_ruby_value(resource:, event:, enrichment:, service_integration:)
    end

    it "fetches the data key from the enrichment if from_enrichment is true" do
      col = described_class.new(:enrichment_val, described_class::TEXT, data_key: "note", from_enrichment: true)
      v = to_ruby_value(col, {}, nil, {"note" => "apple banana"})
      expect(v).to eq("apple banana")
    end

    it "can optionally fetch from the enrichment" do
      col = described_class.new(:canceled_at, described_class::TIMESTAMP, from_enrichment: true, optional: true)
      v = to_ruby_value(col, {}, nil, {})
      expect(v).to be_nil
    end

    it "fetches the event key from the event if there is an event and event key" do
      col = described_class.new(:event_type, described_class::TEXT, event_key: "type")
      v = to_ruby_value(col, {}, {"type" => "note_updated"}, nil)
      expect(v).to eq("note_updated")
    end

    it "always treats event keys as required" do
      col = described_class.new(:quantity, described_class::INTEGER, event_key: "new_quantity", optional: true)
      expect do
        to_ruby_value(col, {}, {}, nil)
      end.to raise_error(KeyError, /key not found: 'new_quantity/)
    end

    it "falls back to fetching the data key from the resource" do
      col = described_class.new(:status, described_class::TEXT, event_key: "status")
      v = to_ruby_value(col, {"status" => "inactive"}, nil, nil)
      expect(v).to eq("inactive")
    end

    it "errors if a key is missing and required" do
      col = described_class.new(:id, described_class::BIGINT)
      expect do
        to_ruby_value(col, {}, nil, nil)
      end.to raise_error(KeyError, /key not found: 'id'/)
    end

    it "returns nil if a key is missing and optional" do
      col = described_class.new(:discounted_price, described_class::FLOAT, optional: true)
      v = to_ruby_value(col, {}, nil, nil)
      expect(v).to be_nil
    end

    it "can use an array of keys" do
      col = described_class.new(
        :membership_active,
        described_class::BOOLEAN,
        data_key: ["membership", "is_active"],
      )
      v = to_ruby_value(col, {"membership" => {"is_active" => true}}, nil, nil)
      expect(v).to be(true)
    end

    it "will use nil if an intermediate key is missing and optional" do
      col = described_class.new(
        :end_date,
        described_class::DATE,
        data_key: ["vacation", "duration", "end_date"],
        optional: true,
      )
      v = to_ruby_value(col, {"vacation" => {}}, nil, nil)
      expect(v).to be_nil
    end

    it "calls the defaulter with the resource if the value is nil and a defaulter is present" do
      # This defaulter is tested elsewhere in this file
      col = described_class.new(
        :updated_at,
        described_class::TIMESTAMP,
        optional: true,
        defaulter: described_class.defaulter_from_resource_field(:created_at),
      )
      v = to_ruby_value(col, {"created_at" => DateTime.new(1992, 4, 7)}, nil, nil)
      expect(v).to eq(DateTime.new(1992, 4, 7))
    end

    it "calls the converter if present" do
      # This converter is tested elsewhere in this file
      col = described_class.new(
        :number,
        described_class::INTEGER,
        converter: Webhookdb::Replicator::Column::CONV_TO_I,
      )
      v = to_ruby_value(col, {"number" => "15367"}, nil, nil)
      expect(v).to eq(15_367)
    end

    describe "with a column type OBJECT" do
      let(:col) { described_class.new(:extra, described_class::OBJECT) }

      it "calls to_json if the value is not a string or nil" do
        obj = {"first_letter" => "a", "last_letter" => "z"}
        v = to_ruby_value(col, {"extra" => obj}, nil, nil)
        expect(v).to eq(obj.to_json)
      end

      it "uses nil if the value is nil" do
        v = to_ruby_value(col, {"extra" => nil}, nil, nil)
        expect(v).to be_nil
      end

      it "uses the value if the value is a string" do
        v = to_ruby_value(col, {"extra" => "bonus info"}, nil, nil)
        expect(v).to eq("bonus info")
      end
    end

    describe "with a column type INTEGER_ARRAY" do
      let(:col) { described_class.new(:intarr, described_class::INTEGER_ARRAY) }

      def to_sql(pgarr)
        ds = Webhookdb::Postgres::Model.db[:x]
        s = +""
        pgarr.sql_literal_append(ds, s)
        return s
      end
      it "handles an array with values" do
        v = to_ruby_value(col, {"intarr" => [1, 2, 3]}, nil, nil)
        expect(to_sql(v)).to eq("ARRAY[1,2,3]::integer[]")
      end

      it "handles an empty array" do
        v = to_ruby_value(col, {"intarr" => []}, nil, nil)
        expect(to_sql(v)).to eq("'{}'::integer[]")
      end

      it "uses null if null" do
        v = to_ruby_value(col, {"intarr" => nil}, nil, nil)
        expect(v).to be_nil
      end

      it "applies to a column with a custom converter" do
        col = described_class.new(:textarr, described_class::INTEGER_ARRAY, converter: identity_conv)
        v = to_ruby_value(col, {"textarr" => [1]}, nil, nil)
        expect(to_sql(v)).to eq("ARRAY[1]::integer[]")
      end
    end

    describe "with a column type TEXT_ARRAY" do
      let(:col) { described_class.new(:textarr, described_class::TEXT_ARRAY) }

      def to_sql(pgarr)
        ds = Webhookdb::Postgres::Model.db[:x]
        s = +""
        pgarr.sql_literal_append(ds, s)
        return s
      end
      it "handles an array with values" do
        v = to_ruby_value(col, {"textarr" => ["a", "b", "c"]}, nil, nil)
        expect(to_sql(v)).to eq("ARRAY['a','b','c']::text[]")
      end

      it "handles an empty array" do
        v = to_ruby_value(col, {"textarr" => []}, nil, nil)
        expect(to_sql(v)).to eq("'{}'::text[]")
      end

      it "uses null if null" do
        v = to_ruby_value(col, {"textarr" => nil}, nil, nil)
        expect(v).to be_nil
      end

      it "applies to a column with a custom converter" do
        col = described_class.new(:textarr, described_class::TEXT_ARRAY, converter: identity_conv)
        v = to_ruby_value(col, {"textarr" => ["a"]}, nil, nil)
        expect(to_sql(v)).to eq("ARRAY['a']::text[]")
      end
    end
  end

  describe "to_sql_expr" do
    table = :column_to_sql_expr_test

    before(:all) do
      @conn = Webhookdb::Dbutil.take_conn(Webhookdb::Postgres::Model.uri, extensions: [:pg_json])
    end

    after(:all) do
      @conn.drop_table?(table)
      @conn.disconnect
    end

    before(:each) do
      @conn.drop_table?(table)
      @conn.create_table(table) do
        jsonb :data
        jsonb :enrichment
        Webhookdb::DBAdapter::PG::COLTYPE_MAP.each do |(k, v)|
          column "col_#{k}".to_sym, v
        end
      end
    end

    let(:ds) { @conn[table] }

    it "can extract all supported types from the data column" do
      ds.insert(
        data: {
          col_bigint: 1,
          col_bool: true,
          col_date: "2020-10-31",
          col_decimal: 1.1,
          col_double: 0.5,
          col_float: 0.6,
          col_int: 2,
          col_object: '{"x": 1}',
          col_text: "hi",
          col_timestamp: "2020-10-31T12:00:00Z",
        }.to_json,
      )
      ds.update(
        col_bigint: described_class.new(:col_bigint, described_class::BIGINT).to_sql_expr,
        col_bool: described_class.new(:col_bool, described_class::BOOLEAN).to_sql_expr,
        col_date: described_class.new(:col_date, described_class::DATE).to_sql_expr,
        col_decimal: described_class.new(:col_decimal, described_class::DECIMAL).to_sql_expr,
        col_double: described_class.new(:col_double, described_class::DOUBLE).to_sql_expr,
        col_float: described_class.new(:col_float, described_class::FLOAT).to_sql_expr,
        col_int: described_class.new(:col_int, described_class::INTEGER).to_sql_expr,
        col_object: described_class.new(:col_object, described_class::OBJECT).to_sql_expr,
        col_text: described_class.new(:col_text, described_class::TEXT).to_sql_expr,
        col_timestamp: described_class.new(:col_timestamp, described_class::TIMESTAMP).to_sql_expr,
      )
      expect(ds.first).to include(
        col_bigint: 1,
        col_bool: true,
        col_date: Date.new(2020, 10, 31),
        col_decimal: 1.1,
        col_double: 0.5,
        col_float: 0.6,
        col_int: 2,
        col_object: '{"x": 1}',
        col_text: "hi",
        col_timestamp: Time.parse("2020-10-31T12:00:00Z"),
      )
    end

    it "can extract nested values" do
      ds.insert(
        data: {
          lvl1: {
            lvl2: {
              col_bigint: 1,
              col_bool: true,
              col_date: "2020-10-31",
              col_decimal: 1.1,
              col_double: 0.5,
              col_float: 0.6,
              col_int: 2,
              col_object: '{"x": 1}',
              col_text: "hi",
              col_timestamp: "2020-10-31T12:00:00Z",
            },
          },
        }.to_json,
      )
      to_expr = proc do |n, t|
        described_class.new(n, t, data_key: ["lvl1", "lvl2", n.to_s]).to_sql_expr
      end
      ds.update(
        col_bigint: to_expr.call(:col_bigint, described_class::BIGINT),
        col_bool: to_expr.call(:col_bool, described_class::BOOLEAN),
        col_date: to_expr.call(:col_date, described_class::DATE),
        col_decimal: to_expr.call(:col_decimal, described_class::DECIMAL),
        col_double: to_expr.call(:col_double, described_class::DOUBLE),
        col_float: to_expr.call(:col_float, described_class::FLOAT),
        col_int: to_expr.call(:col_int, described_class::INTEGER),
        col_object: to_expr.call(:col_object, described_class::OBJECT),
        col_text: to_expr.call(:col_text, described_class::TEXT),
        col_timestamp: to_expr.call(:col_timestamp, described_class::TIMESTAMP),
      )
      expect(ds.first).to include(
        col_bigint: 1,
        col_bool: true,
        col_date: Date.new(2020, 10, 31),
        col_decimal: 1.1,
        col_double: 0.5,
        col_float: 0.6,
        col_int: 2,
        col_object: '{"x": 1}',
        col_text: "hi",
        col_timestamp: Time.parse("2020-10-31T12:00:00Z"),
      )
    end

    it "can extract from the enrichment column instead of the data column" do
      ds.insert(enrichment: {col_bigint: 1}.to_json)
      ds.update(
        col_bigint: described_class.new(:col_bigint, described_class::BIGINT, from_enrichment: true).to_sql_expr,
      )
      expect(ds.first).to include(col_bigint: 1)
    end

    it "can apply a conversion to the extraction expression" do
      ds.insert(data: {col_timestamp: 100}.to_json)
      col = described_class.new(
        :col_timestamp,
        described_class::TIMESTAMP,
        converter: described_class::CONV_UNIX_TS,
      )
      ds.update(col_timestamp: col.to_sql_expr)
      expect(ds.first).to include(col_timestamp: Time.parse("1970-01-01T00:01:40Z"))
    end

    it "coalesces a default" do
      ds.insert(data: {}.to_json)
      ds.update(
        col_bool: described_class.new(
          :col_bool,
          described_class::BOOLEAN,
          defaulter: described_class::DEFAULTER_FALSE,
        ).to_sql_expr,
        col_timestamp: described_class.new(
          :col_timestamp,
          described_class::TIMESTAMP,
          defaulter: described_class::DEFAULTER_NOW,
        ).to_sql_expr,
      )
      expect(ds.first).to include(
        col_bool: false,
        col_timestamp: be > Time.parse("2022-07-28T12:00:00Z"),
      )
    end

    it "applies a conversion to the expression and not the default" do
      ds.insert(data: {}.to_json)
      ds.insert(data: {col_timestamp: 100}.to_json)
      ds.update(
        col_timestamp: described_class.new(
          :col_timestamp,
          described_class::TIMESTAMP,
          converter: described_class::CONV_UNIX_TS,
          defaulter: described_class::DEFAULTER_NOW,
        ).to_sql_expr,
      )
      expect(ds.order(:col_timestamp).first).to include(col_timestamp: Time.parse("1970-01-01T00:01:40Z"))
      expect(ds.order(:col_timestamp).last).to include(col_timestamp: be > Time.parse("2022-07-28T12:00:00Z"))
    end
  end

  describe "converters" do
    describe "CONV_UNIX_TS" do
      let(:initial_value) { 1_530_291_411 }
      let(:expected_value) { Time.at(1_530_291_411) }

      it_behaves_like "a service column converter", described_class::CONV_UNIX_TS

      describe "ruby proc" do
        it "handles TypeError" do
          v = described_class::CONV_UNIX_TS.ruby.call("John Smith")
          expect(v).to be_nil
        end
      end

      describe "sql proc" do
        it "errors on invalid casts (until support is added)" do
          e = described_class::CONV_UNIX_TS.sql.call("John Smith")
          expect do
            Webhookdb::Postgres::Model.db.select(e).first
          end.to raise_error(Sequel::DatabaseError)
        end
      end
    end

    describe "CONV_TO_I" do
      let(:initial_value) { "100" }
      let(:expected_value) { 100 }

      it_behaves_like "a service column converter", described_class::CONV_TO_I
    end

    describe "CONV_PARSE_TIME" do
      let(:initial_value) { "Thu, 30 Jul 2015 20:12:31 +0000" }
      let(:expected_value) { "2015-07-30 20:12:31.000000000 +0000" }

      it_behaves_like "a service column converter", described_class::CONV_PARSE_TIME
    end

    describe "CONV_TO_UTC_DATE" do
      let(:initial_value) { "2020-02-01T03:00:00+1000" }
      let(:expected_value) { Date.new(2020, 1, 31) }

      it_behaves_like "a service column converter", described_class::CONV_TO_UTC_DATE
    end

    describe "converter_from_regex" do
      it "always uses the only group" do
        conv = described_class.converter_from_regex(%r{/[a-z]+/\d+/[a-z]+/(\d+)/[a-z]+})
        expect(conv.ruby.call("/xy/123/ab/45/z")).to eq("45")
      end

      it "returns the specified group index" do
        conv = described_class.converter_from_regex(%r{/([a-z]+)/\d+/[a-z]+/(\d+)/[a-z]+})
        expect(conv.ruby.call("/xy/123/ab/45/z")).to eq("45")

        conv = described_class.converter_from_regex(%r{/([a-z]+)/\d+/[a-z]+/(\d+)/[a-z]+}, index: 0)
        expect(conv.ruby.call("/xy/123/ab/45/z")).to eq("xy")
      end

      it "returns nil if no match" do
        conv = described_class.converter_from_regex(%r{/abc/(\d+)+}, coerce: :to_i)
        expect(conv.ruby.call("/abc/xyz")).to be_nil
      end

      it "returns nil if given nil" do
        conv = described_class.converter_from_regex(%r{/abc/(\d+)+}, coerce: :to_i)
        expect(conv.ruby.call(nil)).to be_nil
      end

      it "can call the given additional method" do
        conv = described_class.converter_from_regex(%r{/\d+/(\d+)+}, coerce: :to_i)
        expect(conv.ruby.call("/xy/123/45/z")).to eq(45)
      end
    end

    describe "converter_int_or_sequence_from_regex" do
      it "uses the regex value if captured" do
        conv = described_class.converter_int_or_sequence_from_regex(%r{/a/(\d+)/b})
        expect(conv.ruby.call("/a/123/b", service_integration: nil)).to eq(123)
      end

      it "uses the service integration sequence if not captured" do
        conv = described_class.converter_int_or_sequence_from_regex(%r{/a/(\d+)/b})
        sint = Webhookdb::Fixtures.service_integration.create
        sint.ensure_sequence(skip_check: true)
        expect(conv.ruby.call("/ab", service_integration: sint)).to eq(1)
      end
    end

    describe "converter_strptime" do
      it "converts the value using the specified format" do
        conv = described_class.converter_strptime("%Y%m%dT%H%M%S%Z")
        expect(conv.ruby.call("19970714T173000Z")).to eq(Time.rfc2822("Mon, 14 Jul 1997 17:30:00 -0000"))
        conv = described_class.converter_strptime("%Y%m%d", cls: Date)
        expect(conv.ruby.call("19970714")).to eq(Date.new(1997, 7, 14))
      end

      it "raises for an invalid value" do
        conv = described_class.converter_strptime("%Y%m")
        expect { conv.ruby.call("1") }.to raise_error(/invalid date or strptime format/)
      end

      it "uses nil if value is nil" do
        conv = described_class.converter_strptime("%Y%m%d")
        expect(conv.ruby.call(nil)).to be_nil
      end
    end

    describe "converter_gsub" do
      it "converts with gsub" do
        conv = described_class.converter_gsub(/^xyz/, "abc")
        expect(conv.ruby.call("xyz://123")).to eq("abc://123")
        expect(conv.ruby.call("xyz://xyz")).to eq("abc://xyz")
        expect(conv.ruby.call("abc://xyz")).to eq("abc://xyz")
        conv = described_class.converter_gsub("xyz", "abc")
        expect(conv.ruby.call("xyz://xyz")).to eq("abc://abc")
        expect(conv.ruby.call(nil)).to be_nil
      end
    end

    describe "CONV_COMMA_SEP" do
      it "converts the value" do
        conv = described_class::CONV_COMMA_SEP
        expect(conv.ruby.call("a,b")).to eq(["a", "b"])
        expect(conv.ruby.call(" a, b ")).to eq(["a", "b"])
        expect(conv.ruby.call("a")).to eq(["a"])
        expect(conv.ruby.call("")).to eq([])
        expect(conv.ruby.call(nil)).to eq([])
      end
    end

    describe "Webhookdb::Replicator::ConvertkitV1Mixin::CONV_FIND_CANCELED_AT" do
      let(:conv) { Webhookdb::Replicator::ConvertkitV1Mixin::CONV_FIND_CANCELED_AT }

      describe "ruby proc" do
        it "returns nil when state is active" do
          v = conv.ruby.call(nil, resource: {"state" => "active"})
          expect(v).to be_nil
        end

        it "returns now when state is not active" do
          v = conv.ruby.call(nil, resource: {"state" => "inactive"})
          expect(v).to be_within(10).of(Time.now)
        end
      end

      describe "sql proc" do
        it "is nil because this has external dependencies" do
          expect(conv.sql).to be_nil
        end
      end
    end

    describe "Webhookdb::Replicator::TheranestV1Mixin::CONV_PARSE_MDY_SLASH" do
      let(:initial_value) { "04/07/1992" }
      let(:expected_value) { Date.new(1992, 4, 7) }

      it_behaves_like "a service column converter", Webhookdb::Replicator::TheranestV1Mixin::CONV_PARSE_MDY_SLASH

      describe "ruby proc" do
        it "handles Date::Error" do
          v = Webhookdb::Replicator::TheranestV1Mixin::CONV_PARSE_MDY_SLASH.ruby.call("John Smith")
          expect(v).to be_nil
        end

        it "handles TypeError" do
          v = Webhookdb::Replicator::TheranestV1Mixin::CONV_PARSE_MDY_SLASH.ruby.call(100)
          expect(v).to be_nil
        end
      end

      describe "sql proc" do
        it "ignores invalid strings" do
          v = Webhookdb::Replicator::TheranestV1Mixin::CONV_PARSE_MDY_SLASH.sql.call("John Smith")
          expect(Webhookdb::Postgres::Model.db.select(v).first).to include(case: nil)
        end

        it "ignores non-strings" do
          v = Webhookdb::Replicator::TheranestV1Mixin::CONV_PARSE_MDY_SLASH.sql.call(100)
          expect(Webhookdb::Postgres::Model.db.select(v).first).to include(case: nil)
        end
      end
    end

    describe "Webhookdb::Replicator::TheranestV1Mixin::CONV_PARSE_YMD_SLASH" do
      let(:initial_value) { "1992/04/07" }
      let(:expected_value) { Date.new(1992, 4, 7) }

      it_behaves_like "a service column converter", Webhookdb::Replicator::TheranestV1Mixin::CONV_PARSE_YMD_SLASH

      describe "ruby proc" do
        it "handles Date::Error" do
          v = Webhookdb::Replicator::TheranestV1Mixin::CONV_PARSE_YMD_SLASH.ruby.call("John Smith")
          expect(v).to be_nil
        end

        it "handles TypeError" do
          v = Webhookdb::Replicator::TheranestV1Mixin::CONV_PARSE_YMD_SLASH.ruby.call(100)
          expect(v).to be_nil
        end
      end

      describe "sql proc" do
        it "ignores invalid strings" do
          v = Webhookdb::Replicator::TheranestV1Mixin::CONV_PARSE_YMD_SLASH.sql.call("John Smith")
          expect(Webhookdb::Postgres::Model.db.select(v).first).to include(case: nil)
        end

        it "ignores non-strings" do
          v = Webhookdb::Replicator::TheranestV1Mixin::CONV_PARSE_YMD_SLASH.sql.call(100)
          expect(Webhookdb::Postgres::Model.db.select(v).first).to include(case: nil)
        end
      end
    end

    describe "Webhookdb::Replicator::TheranestV1Mixin::CONV_PARSE_DATETIME" do
      let(:initial_value) { "04/07/1992 12:04 AM" }
      let(:expected_value) { Time.parse("1992-04-07T00:04:00-0700") }

      it_behaves_like "a service column converter", Webhookdb::Replicator::TheranestV1Mixin::CONV_PARSE_DATETIME

      describe "ruby proc" do
        it "handles Date::Error" do
          v = Webhookdb::Replicator::TheranestV1Mixin::CONV_PARSE_DATETIME.ruby.call("John Smith")
          expect(v).to be_nil
        end

        it "handles TypeError" do
          v = Webhookdb::Replicator::TheranestV1Mixin::CONV_PARSE_DATETIME.ruby.call(100)
          expect(v).to be_nil
        end
      end

      describe "sql proc" do
        it "ignores invalid strings" do
          v = Webhookdb::Replicator::TheranestV1Mixin::CONV_PARSE_DATETIME.sql.call("John Smith")
          expect(Webhookdb::Postgres::Model.db.select(v).first).to include(case: nil)
        end

        it "ignores non-strings" do
          v = Webhookdb::Replicator::TheranestV1Mixin::CONV_PARSE_DATETIME.sql.call(100)
          expect(Webhookdb::Postgres::Model.db.select(v).first).to include(case: nil)
        end
      end
    end

    describe "Webhookdb::Replicator::TransistorEpisodeStatsV1::CONV_PARSE_DMY_DASH" do
      let(:initial_value) { "07-04-1992" }
      let(:expected_value) { Date.new(1992, 4, 7) }

      it_behaves_like "a service column converter", Webhookdb::Replicator::TransistorEpisodeStatsV1::CONV_PARSE_DMY_DASH
    end

    describe "Webhookdb::Replicator::TransistorEpisodeStatsV1::CONV_REMOTE_KEY" do
      let(:converter) { Webhookdb::Replicator::TransistorEpisodeStatsV1::CONV_REMOTE_KEY }
      let(:initial_value) { "2022-06-13" }
      let(:resource) { {"date" => "2022-06-13", "episode_id" => "abc", "downloads" => 2} }
      let(:expected_value) { "abc-2022-06-13" }

      it "returns expected value using ruby proc" do
        v = converter.ruby.call(initial_value, resource:)
        expect(v).to eq(expected_value)
      end

      it "returns expected value using sql proc" do
        e = converter.sql.call(initial_value)
        v = Webhookdb::Postgres::Model.db.select(e).first.to_a[0][1]
        expect(v).to eq("do not use")
      end
    end
  end

  describe "defaulters" do
    describe "DEFAULTER_NOW" do
      it_behaves_like "a service column defaulter", Webhookdb::Replicator::Column::DEFAULTER_NOW do
        let(:expected) { be_within(10).of(Time.now) }
      end
    end

    describe "DEFAULTER_FALSE" do
      it_behaves_like "a service column defaulter", Webhookdb::Replicator::Column::DEFAULTER_FALSE do
        let(:expected_value) { false }
      end
    end

    describe "defaulter_from_resource_field" do
      it_behaves_like "a service column defaulter", described_class.defaulter_from_resource_field(:x) do
        let(:resource) { {"x" => "2022-06-13T14:21:04.123Z"} }
        let(:expected_value) { "2022-06-13T14:21:04.123Z" }
        let(:expected_query) { 'SELECT "x"' }
      end
    end

    describe "DEFAULTER_FROM_INTEGRATION_SEQUENCE" do
      it_behaves_like "a service column defaulter", described_class::DEFAULTER_FROM_INTEGRATION_SEQUENCE do
        let(:resource) { {} }
        let(:service_integration) do
          sint = Webhookdb::Fixtures.service_integration.create
          sint.ensure_sequence(skip_check: true)
          sint
        end
        let(:expected_value) { 1 }
        let(:expected_query) { /SELECT nextval\('replicator_seq_org_/ }
      end
    end
  end
end
