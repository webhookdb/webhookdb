# frozen_string_literal: true

require "rspec/eventually"
require "webhookdb/async/job"

RSpec.describe Webhookdb::Async::Job, :async, :db do
  describe "lookup_model" do
    let(:job) do
      Class.new do
        extend Webhookdb::Async::Job
      end
    end

    let(:model_class) do
      Class.new do
        def self.name
          return "TestModel"
        end

        def self.[](idx)
          return idx == 1 ? "found" : nil
        end
      end
    end

    it "returns the model with that ID if it exists" do
      expect(job.new.lookup_model(model_class, 1)).to_not be_nil
    end

    it "raises if there is no model with that ID" do
      expect do
        job.new.lookup_model(model_class, 2)
      end.to raise_error(/TestModel\[2\] does not exist/)
    end

    it "will use the first item in payload if the argument is an array" do
      expect(job.new.lookup_model(model_class, [1, "something_else"])).to_not be_nil
    end

    it "will use the first item in the event payload if the argument response to :payload" do
      event = Webhookdb::Event.new(nil, nil, [1, "something else"])
      expect(job.new.lookup_model(model_class, event)).to_not be_nil
    end
  end

  context "attribute-change matchers" do
    let(:subclass) do
      Class.new do
        extend Webhookdb::Async::Job
      end
    end
    let(:instance) { subclass.new }

    it "raises an exception if given any options but :to and :from" do
      expect do
        instance.changed(:thing, at: 5)
      end.to raise_error(ScriptError, /unhandled change option/i)
    end

    it "raises an exception if given a to: that is anything but an immediate value, Proc or a Regexp" do
      matcher = instance.changed(:thing, to: $stderr)
      expect do
        matcher === {"thing" => [1, 2]}
      end.to raise_error(TypeError, /unhandled type of 'to' criteria/i)
    end

    it "raises an exception if given a from: that is anything but an immediate value, Proc or a Regexp" do
      matcher = instance.changed(:thing, from: $stderr)
      expect do
        matcher === {"thing" => [1, 2]}
      end.to raise_error(TypeError, /unhandled type of 'from' criteria/i)
    end

    context "for any change to the password attribute" do
      let(:matcher) { instance.changed(:password) }

      it "matches if the attribute changes include the password field" do
        expect(matcher).to be === {
          "password" => ["foo", "bar"],
          "first_name" => ["James", "Jimmy"],
        }
      end

      it 'does not match if the attribute changes does not include "password"' do
        expect(matcher).to_not be === {
          "activation_code" => ["foo", nil],
          "first_name" => ["James", "Jimmy"],
        }
      end

      it "returns false if the changes are nil" do
        expect(matcher.nil?).to be_falsey
      end
    end

    context "for any change that sets the activation_code to nil" do
      let(:matcher) { instance.changed(:activation_code, to: nil) }

      it "matches if the attribute changes include activation_code being set to nil" do
        expect(matcher).to be === {
          "password" => ["foo", "bar"],
          "activation_code" => ["foo", nil],
        }
      end

      it 'does not match if the attribute changes does not include "activation_code"' do
        expect(matcher).to_not be === {
          "password" => ["foo", nil],
          "first_name" => ["James", "Jimmy"],
        }
      end

      it "does not match if the attribute changes include activation_code being set to something other than nil" do
        expect(matcher).to_not be === {
          "password" => ["foo", "bar"],
          "activation_code" => [nil, "foo"],
        }
      end

      it "returns false if the changes are nil" do
        expect(matcher.nil?).to be_falsey
      end
    end

    context "for any change that sets the count attribute from 0 to anything else" do
      let(:matcher) { instance.changed(:count, from: 0) }

      it "matches if the attribute changes include count being set from 0" do
        expect(matcher).to be === {
          "count" => [0, 18],
          "type" => ["foo", nil],
        }
      end

      it 'does not match if the attribute changes does not include "count"' do
        expect(matcher).to_not be === {
          "password" => ["foo", nil],
          "first_name" => ["James", "Jimmy"],
        }
      end

      it "does not match if the attribute changes include count being set from something other than 0" do
        expect(matcher).to_not be === {
          "password" => ["foo", "bar"],
          "count" => [18, 19],
        }
      end

      it "returns false if the changes are nil" do
        expect(matcher.nil?).to be_falsey
      end
    end

    context "for any change that sets the first_name attribute from a value matching a pattern to anything else" do
      let(:matcher) { instance.changed(:first_name, from: /^Barb/) }

      it "matches if the attribute changes include first_name being set from a value that matches the pattern" do
        expect(matcher).to be === {
          "count" => [0, 18],
          "first_name" => ["Barb", "Barbafet"],
        }
      end

      it 'does not match if the attribute changes does not include "first_name"' do
        expect(matcher).to_not be === {
          "password" => ["foo", nil],
          "last_name" => ["Mulhoney", "Mulrooney"],
        }
      end

      it "does not match if the attribute changes include first_name being set from " \
        "something that does not match the pattern" do
        expect(matcher).to_not be === {
          "password" => ["foo", "bar"],
          "first_name" => ["James", "Hodintyon"],
        }
      end

      it "returns false if the changes are nil" do
        expect(matcher.nil?).to be_falsey
      end
    end

    context "for any change that sets the email attribute to a value matching a pattern from anything else" do
      let(:matcher) { instance.changed(:email, to: /@lithic\.tech\z/i) }

      it "matches if the attribute changes include email being set to a value that matches the pattern" do
        expect(matcher).to be === {
          "count" => [0, 18],
          "email" => ["triplet.3@gmail.com", "barbafet@lithic.tech"],
        }
      end

      it 'does not match if the attribute changes does not include "email"' do
        expect(matcher).to_not be === {
          "password" => ["foo", nil],
          "last_name" => ["Mulhoney", "Mulrooney"],
        }
      end

      it "does not match if the attribute changes include email being set to " \
        "something that does not match the pattern" do
        expect(matcher).to_not be === {
          "password" => ["foo", "bar"],
          "email" => ["wooley@carbuncle.net", "whimsey@webhookdb.dev"],
        }
      end

      it "returns false if the changes are nil" do
        expect(matcher.nil?).to be_falsey
      end
    end

    context 'for any change that sets the type attribute from "eater" to "seeder"' do
      let(:matcher) { instance.changed(:type, from: "eater", to: "seeder") }

      it 'matches if the attribute changes include type being set from "eater" to "seeder"' do
        expect(matcher).to be === {
          "count" => [0, 18],
          "type" => ["eater", "seeder"],
        }
      end

      it 'does not match if the attribute changes does not include "type"' do
        expect(matcher).to_not be === {
          "password" => ["foo", nil],
          "first_name" => ["James", "Jimmy"],
        }
      end

      it 'does not match if the attribute changes include type being set from something other than "eater"' do
        expect(matcher).to_not be === {
          "password" => ["foo", "bar"],
          "type" => ["gazelle", "seeder"],
        }
      end

      it 'does not match if the attribute changes include type being set to something other than "seeder"' do
        expect(matcher).to_not be === {
          "password" => ["foo", "bar"],
          "type" => ["eater", "feeder"],
        }
      end

      it "returns false if the changes are nil" do
        expect(matcher.nil?).to be_falsey
      end
    end

    it "matches :to procs by calling them with the new value" do
      matcher = instance.changed(:type, to: ->(v) { v == "seeder" })
      expect(matcher).to be === {"type" => [nil, "seeder"]}
      expect(matcher).to_not be === {"type" => [nil, "eater"]}
      expect(matcher).to_not be === {"type" => ["seeder", nil]}
    end

    it "matches :from procs by calling them with the old value" do
      matcher = instance.changed(:type, from: ->(v) { v == "seeder" })
      expect(matcher).to be === {"type" => ["seeder", nil]}
      expect(matcher).to_not be === {"type" => ["eater", nil]}
      expect(matcher).to_not be === {"type" => [nil, "seeder"]}
    end
  end

  context "indexed (Hash) attribute-change matchers" do
    let(:subclass) do
      Class.new do
        extend Webhookdb::Async::Job
      end
    end
    let(:instance) { subclass.new }

    context "for any change to a field in a hash" do
      let(:matcher) { instance.changed_at(:flags, :f) }

      it "matches if a key is added" do
        expect(matcher).to be === {
          "flags" => [nil, {"f" => true}],
        }
      end

      it "matches if a value changes" do
        expect(matcher).to be === {
          "flags" => [{"f" => false}, {"f" => true}],
        }
      end

      it "does not match if the field at the index did not change" do
        expect(matcher).to_not be === {
          "flags" => [{"f" => true}, {"f" => true, "z" => true}],
        }
      end

      it "returns false if the changes are nil" do
        expect(matcher.nil?).to be_falsey
      end
    end

    context "for a change to a value" do
      let(:matcher) { instance.changed_at(:stuff, :b, to: 5) }

      it "matches if the index changes to that value" do
        expect(matcher).to be === {
          "stuff" => [{"b" => 2}, {"b" => 5}],
        }
      end

      it "does not match if the index changes to a different value" do
        expect(matcher).to_not be === {
          "stuff" => [{"b" => 2}, {"b" => 4}],
        }
      end

      it "returns false if the changes are nil" do
        expect(matcher.nil?).to be_falsey
      end
    end

    context "for a change from a value" do
      let(:matcher) { instance.changed_at(:stuff, :b, from: 2) }

      it "matches if the index changes from that value" do
        expect(matcher).to be === {
          "stuff" => [{"b" => 2}, {"b" => 5}],
        }
      end

      it "does not match if the index changes from a different value" do
        expect(matcher).to_not be === {
          "stuff" => [{"b" => 0}, {"b" => 5}],
        }
      end

      it "returns false if the changes are nil" do
        expect(matcher.nil?).to be_falsey
      end
    end

    context "for a change from a given value to a different given value" do
      let(:matcher) { instance.changed_at(:stuff, :b, from: 2, to: 5) }

      it 'matches if the index changes from the given "from" value to the given "to" value' do
        expect(matcher).to be === {
          "stuff" => [{"b" => 2}, {"b" => 5}],
        }
      end

      it "does not match if the index changes from a different value" do
        expect(matcher).to_not be === {
          "stuff" => [{"b" => 0}, {"b" => 5}],
        }
      end

      it "does not match if the index changes to a different value" do
        expect(matcher).to_not be === {
          "stuff" => [{"b" => 2}, {"b" => 4}],
        }
      end

      it "returns false if the changes are nil" do
        expect(matcher.nil?).to be_falsey
      end
    end
  end
end
