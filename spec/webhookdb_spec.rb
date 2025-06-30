# frozen_string_literal: true

require "tempfile"

require "webhookdb"

RSpec.describe Webhookdb do
  describe "configuration" do
    before(:each) do
      @tempfiles = []
    end

    after(:each) do
      @tempfiles.each { |t| t.close(true) }
    end

    def new_tmp
      tmp = Tempfile.new("webhookdb-spec")
      @tempfiles << tmp
      yield(tmp) if block_given?
      tmp.flush
      return tmp
    end
  end

  describe "load_fixture_data" do
    it "loads plain-text fixture data" do
      data = load_fixture_data("plain.txt")
      expect(data).to eq("Yep!\n")
    end

    it "loads JSON fixture data" do
      data = load_fixture_data("stuff.json")
      expect(data).to eq("here" => "is some JSON stuff")
    end

    it "loads YAML fixture data" do
      data = load_fixture_data("stuff.yml")
      expect(data).to eq("here" => "is some YAML stuff")
    end

    it "loads JSON fixture data without an extension" do
      data = load_fixture_data(:stuff)
      expect(data).to eq("here" => "is some JSON stuff")
    end

    it "falls back on YAML fixture data if there's no JSON file when loading without an extension" do
      data = load_fixture_data(:other_stuff)
      expect(data).to eq("here" => "is some other YAML stuff")
    end
  end

  describe "idempotency keys" do
    before(:each) do
      @bust_idem = described_class.bust_idempotency
      described_class.bust_idempotency = false
    end

    after(:each) do
      described_class.bust_idempotency = @bust_idem
    end

    it "is the same for the same model instance" do
      customer = Webhookdb::Customer.new
      key1 = described_class.idempotency_key(customer)
      key2 = described_class.idempotency_key(customer)
      expect(key1).to eq(key2)
    end

    it "is the same for models with the same type and primary key" do
      customer1 = Webhookdb::Customer.new
      customer1.id = 1
      customer2 = Webhookdb::Customer.new
      customer2.id = 1

      key1 = described_class.idempotency_key(customer1)
      key2 = described_class.idempotency_key(customer2)
      expect(key1).to eq(key2)
    end

    it "is unique for the same model type with different ids" do
      customer1 = Webhookdb::Customer.new
      customer1.id = 1
      customer2 = Webhookdb::Customer.new
      customer2.id = 2

      key1 = described_class.idempotency_key(customer1)
      key2 = described_class.idempotency_key(customer2)
      expect(key1).to_not eq(key2)
    end

    it "is unique for model types" do
      customer = Webhookdb::Customer.new
      person = Webhookdb::Role.new

      customerkey = described_class.idempotency_key(customer)
      personkey = described_class.idempotency_key(person)
      expect(customerkey).to_not eq(personkey)
    end

    it "is randomized if bust_idempotency is true" do
      described_class.bust_idempotency = true
      customer = Webhookdb::Customer.new
      key1 = described_class.idempotency_key(customer)
      key2 = described_class.idempotency_key(customer)
      expect(key1).to_not eq(key2)
    end

    it "is unique when different `parts` are passed" do
      customer = Webhookdb::Customer.new
      no_parts = described_class.idempotency_key(customer)
      part_a = described_class.idempotency_key(customer, "parta")
      part_b = described_class.idempotency_key(customer, "partb")
      two_parts = described_class.idempotency_key(customer, "part1", "part2")

      expect([no_parts, part_a, part_b, two_parts].uniq.count).to eq(4)
    end

    it "is unique on updated_at if updated_at is defined and not empty" do
      customer = Webhookdb::Customer.new
      key1 = described_class.idempotency_key(customer)
      customer.updated_at = Time.now
      key2 = described_class.idempotency_key(customer)
      expect(key1).to_not eq(key2)
    end

    it "is unique on created_at if updated_at is empty or undefined and created_at is defined" do
      customer = Webhookdb::Customer.new
      customer.created_at = Time.now - 1.second
      key1 = described_class.idempotency_key(customer)
      customer.created_at = Time.now
      key2 = described_class.idempotency_key(customer)
      expect(key1).to_not eq(key2)
    end

    it "does not use created_at or updated_at if the model does not have it" do
      pixie = Webhookdb::Postgres::TestingPixie.new
      pixie.id = 10
      key = described_class.idempotency_key(pixie)
      eq_key = described_class.idempotency_key(pixie)
      expect(key).to eq(eq_key)

      pixie.id = 11
      neq_key = described_class.idempotency_key(pixie)
      expect(key).to_not eq(neq_key)
    end
  end

  describe "to_slug" do
    it "adheres to its spec" do
      expect(described_class.to_slug("")).to eq("")
      expect(described_class.to_slug(" ")).to eq("")
      expect(described_class.to_slug("A B C")).to eq("a_b_c")
      expect(described_class.to_slug("ABC")).to eq("abc")
      expect(described_class.to_slug(" ABC ")).to eq("abc")
      expect(described_class.to_slug("a1-23")).to eq("a1_23")
      expect(described_class.to_slug("a1- --23")).to eq("a1_23")
      expect(described_class.to_slug("1two")).to eq("onetwo")
      expect(described_class.to_slug("12")).to eq("one2")
      expect(described_class.to_slug("1_abc")).to eq("one_abc")
    end
  end

  describe "request users" do
    it "can get and set the request user" do
      expect(described_class.request_user_and_admin).to eq([nil, nil])
      described_class.set_request_user_and_admin(1, 2)
      expect(described_class.request_user_and_admin).to eq([1, 2])
      described_class.set_request_user_and_admin(nil, nil)
      expect(described_class.request_user_and_admin).to eq([nil, nil])
    end

    it "can set request user with a block" do
      expect(described_class.request_user_and_admin).to eq([nil, nil])
      described_class.set_request_user_and_admin(1, 2) do
        expect(described_class.request_user_and_admin).to eq([1, 2])
      end
      expect(described_class.request_user_and_admin).to eq([nil, nil])
    end

    it "errors when setting request user multiple times" do
      # this is okay
      described_class.set_request_user_and_admin(nil, nil)
      described_class.set_request_user_and_admin(nil, nil)
      # this will not be
      described_class.set_request_user_and_admin(1, 2)
      expect { described_class.set_request_user_and_admin(1, 2) }.to raise_error(Webhookdb::InvalidPrecondition)
    ensure
      described_class.set_request_user_and_admin(nil, nil)
    end
  end

  describe "cached_get", reset_configuration: described_class do
    before(:each) do
      @calls = 0
    end

    it "caches and returns the value if enabled" do
      described_class.use_globals_cache = true
      expect(described_class.cached_get("k") { @calls += 1 }).to eq(1)
      expect(@calls).to eq(1)
      expect(described_class.cached_get("k") { @calls += 1 }).to eq(1)
      expect(@calls).to eq(1)
      expect(described_class.cached_get("j") { @calls += 1 }).to eq(2)
      expect(@calls).to eq(2)
    end

    it "does not cache if enabled" do
      described_class.use_globals_cache = false
      expect(described_class.cached_get("k") { @calls += 1 }).to eq(1)
      expect(described_class.cached_get("k") { @calls += 1 }).to eq(2)
      expect(@calls).to eq(2)
      # Turn it on and make sure it picks up
      described_class.use_globals_cache = true
      expect(described_class.cached_get("k") { @calls += 1 }).to eq(3)
      expect(described_class.cached_get("k") { @calls += 1 }).to eq(3)
      # Turn it back off and make sure cache is ignored
      described_class.use_globals_cache = false
      expect(described_class.cached_get("k") { @calls += 1 }).to eq(4)
      expect(described_class.cached_get("k") { @calls += 1 }).to eq(5)
    end
  end

  describe "parse_bool" do
    it "parses bool" do
      expect(described_class.parse_bool(0)).to be(false)
      expect(described_class.parse_bool(false)).to be(false)
      expect(described_class.parse_bool(nil)).to be(false)
      expect(described_class.parse_bool("")).to be(false)
      expect(described_class.parse_bool(" ")).to be(false)
      expect(described_class.parse_bool("0")).to be(false)
      expect(described_class.parse_bool("FALSE")).to be(false)
      expect(described_class.parse_bool("no")).to be(false)
      expect(described_class.parse_bool("off")).to be(false)
      expect(described_class.parse_bool("f")).to be(false)
      expect(described_class.parse_bool("n")).to be(false)

      expect(described_class.parse_bool(1)).to be(true)
      expect(described_class.parse_bool(2)).to be(true)
      expect(described_class.parse_bool(-1)).to be(true)
      expect(described_class.parse_bool("1")).to be(true)
      expect(described_class.parse_bool("TRUE")).to be(true)
      expect(described_class.parse_bool("yes")).to be(true)
      expect(described_class.parse_bool("on")).to be(true)
      expect(described_class.parse_bool("t")).to be(true)
      expect(described_class.parse_bool("y")).to be(true)

      expect { described_class.parse_bool("?") }.to raise_error(ArgumentError)
      expect { described_class.parse_bool("2") }.to raise_error(ArgumentError)
    end
  end
end
