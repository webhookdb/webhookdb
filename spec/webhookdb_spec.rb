# frozen_string_literal: true

require "tempfile"

require "webhookdb"

RSpec.describe Webhookdb do
  describe "configuration" do
    before do
      @env = ENV[described_class::CONFIG_ENV_VAR]
      @tempfiles = []
    end

    after do
      ENV[described_class::CONFIG_ENV_VAR] = @end
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

  describe "publish", :async do
    it "publishes an event" do
      expect do
        described_class.publish("some-event")
      end.to publish("some-event")
    end

    it "converts all hash keys to strings" do
      expect do
        described_class.publish("some-event", key: {subkey: "subvalue"})
      end.to publish("some-event").with_payload([{"key" => {"subkey" => "subvalue"}}])
    end
  end

  describe "subscribers" do
    it "can register and unregister" do
      calls = []
      sub = described_class.register_subscriber { |e| calls << e }
      described_class.publish("hi")
      described_class.publish("hi")
      expect(calls).to have_length(2)
      described_class.unregister_subscriber(sub)
      described_class.publish("hi")
      expect(calls).to have_length(2)
    end
  end

  describe "Event" do
    it "can convert to/from json" do
      e = Webhookdb::Event.new("event-id", "event-name", [1, 2, 3])
      j = e.to_json
      o = JSON.parse(j)
      e2 = Webhookdb::Event.from_json(o)
      expect(e2).to have_attributes(id: "event-id", name: "event-name", payload: [1, 2, 3])
    end
  end

  describe "idempotency keys" do
    before do
      @bust_idem = described_class.bust_idempotency
      described_class.bust_idempotency = false
    end

    after do
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
      expect(key1).not_to eq(key2)
    end

    it "is unique for model types" do
      customer = Webhookdb::Customer.new
      person = Webhookdb::Role.new

      customerkey = described_class.idempotency_key(customer)
      personkey = described_class.idempotency_key(person)
      expect(customerkey).not_to eq(personkey)
    end

    it "is randomized if bust_idempotency is true" do
      described_class.bust_idempotency = true
      customer = Webhookdb::Customer.new
      key1 = described_class.idempotency_key(customer)
      key2 = described_class.idempotency_key(customer)
      expect(key1).not_to eq(key2)
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
      expect(key1).not_to eq(key2)
    end

    it "is unique on created_at if updated_at is empty or undefined and created_at is defined" do
      customer = Webhookdb::Customer.new
      customer.created_at = Time.now - 1.second
      key1 = described_class.idempotency_key(customer)
      customer.created_at = Time.now
      key2 = described_class.idempotency_key(customer)
      expect(key1).not_to eq(key2)
    end

    it "does not use created_at or updated_at if the model does not have it" do
      pixie = Webhookdb::Postgres::TestingPixie.new
      pixie.id = 10
      key = described_class.idempotency_key(pixie)
      eq_key = described_class.idempotency_key(pixie)
      expect(key).to eq(eq_key)

      pixie.id = 11
      neq_key = described_class.idempotency_key(pixie)
      expect(key).not_to eq(neq_key)
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
end
