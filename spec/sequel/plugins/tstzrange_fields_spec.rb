# frozen_string_literal: true

require "sequel"
require "sequel/model"

require "sequel/plugins/tstzrange_fields"

RSpec.describe Sequel::Plugins::TstzrangeFields, :db do
  context "with no fields given" do
    let(:model_class) do
      mc = create_model(:tstzrange_fields_test) do
        primary_key :id
        tstzrange :period
      end
      mc.class_eval do
        def initialize(*)
          super
          self[:period] ||= self.class.new_tstzrange(nil, nil)
        end
      end
      mc.plugin(:tstzrange_fields)
      mc
    end

    let(:model_object) { model_class.new }

    it "uses :period as the high-level accessor" do
      expect(model_object).to respond_to(:period, :period=, :period_begin, :period_begin=, :period_end, :period_end=)
    end

    it "sets a default empty range" do
      expect(model_object.period).to be_empty
    end
  end

  context "for the given field" do
    let(:model_class) do
      mc = create_model(:tstzrange_fields_test) do
        primary_key :id
        tstzrange :range
      end
      mc.plugin(:tstzrange_fields, :range)
      mc.class_eval do
        def initialize(*)
          super
          self[:range] ||= self.class.new_tstzrange(nil, nil)
        end
      end
      mc
    end

    let(:model_object) { model_class.new }

    let(:t) { Time.at(3.years.ago.to_i) }
    let(:ts) { t.to_s }

    it "sets a default empty range" do
      expect(model_object.range).to be_empty
    end

    it "can set an infinite range by assigning the field to Float::INFINITY" do
      expect(model_object.range).to be_empty

      model_object.range = Float::INFINITY
      expect(model_object.range_begin).to be_nil
      expect(model_object.range_end).to be_nil
      expect(model_object.range).not_to be_empty
      model_object.save_changes
      expect(model_class.where(Sequel.function(:lower_inf, :range)).count).to eq(1)
      expect(model_class.where(Sequel.function(:upper_inf, :range)).count).to eq(1)
    end

    it 'can set an empty range by assigning the field to the string "empty"' do
      model_object.range_begin = t
      model_object.range_end = t + 1.day
      expect(model_object.range).not_to be_empty

      model_object.range = "empty"
      expect(model_object.range).to be_empty
      expect(model_object.range_begin).to be_nil
      expect(model_object.range_end).to be_nil
      model_object.save_changes
      expect(model_class.where(Sequel.function(:lower_inf, :range)).count).to eq(0)
      expect(model_class.where(Sequel.function(:upper_inf, :range)).count).to eq(0)
    end

    it "can get/set the start" do
      model_object.range_begin = t
      expect(model_object.range_begin).to eq(t)
      expect(model_object.save_changes.refresh.range_begin).to eq(t)

      model_object.range_begin = ts
      expect(model_object.range_begin).to eq(t)
      expect(model_object.save_changes.refresh.range_begin).to eq(t)

      model_object.range_begin = nil
      expect(model_object.range_begin).to be_nil
      expect(model_object.save_changes.refresh.range_begin).to be_nil
    end

    it "can get/set the end" do
      model_object.range_end = t
      expect(model_object.range_end).to eq(t)
      expect(model_object.save_changes.refresh.range_end).to eq(t)

      model_object.range_end = ts
      expect(model_object.range_end).to eq(t)
      expect(model_object.save_changes.refresh.range_end).to eq(t)

      model_object.range_end = nil
      expect(model_object.range_end).to be_nil
      expect(model_object.save_changes.refresh.range_end).to be_nil
    end

    it "can initialize an instance using accessors" do
      o = model_class.create(range_begin: nil, range_end: nil)
      expect(o.range).to be_empty

      o = model_class.create(range_begin: Time.now, range_end: 1.hour.from_now)
      expect(o.range).not_to be_cover(30.minutes.ago)
      expect(o.range).to be_cover(30.minutes.from_now)
      expect(o.range).not_to be_cover(90.minutes.from_now)

      o = model_class.create(range_begin: nil, range_end: Time.now)
      expect(o.range).to be_cover(30.minutes.ago)
      expect(o.range).not_to be_cover(30.minutes.from_now)

      o = model_class.create(range_begin: Time.now, range_end: nil)
      expect(o.range).not_to be_cover(30.minutes.ago)
      expect(o.range).to be_cover(30.minutes.from_now)
    end

    it "can be assigned to directly with an object with begin/end methods or keys" do
      early = 1.day.ago
      late = 2.days.from_now

      forms = [
        early...late,
        OpenStruct.new(begin: early, end: late),
        {begin: early, end: late},
        {"begin" => early, "end" => late},
      ]

      forms.each do |value|
        model_object.range = value
        model_object.save_changes.refresh
        expect(model_object.range_begin).to be_within(1).of(early)
        expect(model_object.range_end).to be_within(1).of(late)
      end

      model_object.range = {}
      expect(model_object.range).to be_empty

      expect { model_object.range = 1 }.to raise_error(TypeError)
    end
  end
end
