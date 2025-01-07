# frozen_string_literal: true

require "webhookdb/postgres"

module WebhookdbTestModels; end

RSpec.describe "Webhookdb::Postgres::Model", :db do
  let(:described_class) { Webhookdb::Postgres::Model }

  it "is abstract (doesn't have a dataset of its own)" do
    expect { described_class.dataset }.to raise_error(Sequel::Error, /no dataset/i)
  end

  context "a subclass" do
    it "gets the database connection when one is set on the parent" do
      subclass = create_model(:conn_setter)
      expect(described_class.db).to_not be_nil
      expect(subclass.db).to eq(described_class.db)
    end

    it "registers a topological dependency for associations" do
      subclass = create_model(:allergies)
      other_class = create_model(:food_preferences)
      other_class.many_to_one :related, class: subclass, key: :a_key

      sorted_classes = described_class.tsort
      expect(sorted_classes.index(subclass)).to be < sorted_classes.index(other_class)
    end

    it "doesn't register a dependency for an association marked as ':polymorphic'" do
      animal = create_model(:animals)
      ticket = create_model(:tickets)
      ticket.many_to_one :subject, class: animal, reciprocal: :tickets
      animal.one_to_many :tickets,
                         class: ticket,
                         key: :subject_id,
                         conditions: {subject_type: animal.name},
                         polymorphic: true

      # NameError: uninitialized constant Webhookdb::Ticket
      expect { described_class.tsort }.to_not raise_error
    end

    it "can be extended at runtime via an extension module" do
      extension_mod = Module.new do
        def some_extension_stuff
          return :extension_stuff
        end
      end

      subclass = create_model("modext")
      subclass.add_extensions(extension_mod)

      expect(subclass.new.some_extension_stuff).to eq(:extension_stuff)
    end

    it "can be extended at runtime with class methods via a ClassMethods submodule" do
      extension_mod = Module.new
      extension_mod.const_set :ClassMethods, Module.new
      extension_mod::ClassMethods.module_eval do
        def some_class_extension_stuff
          :class_extension_stuff
        end
      end

      subclass = create_model("classmethods")
      subclass.add_extensions(extension_mod)

      expect(subclass.some_class_extension_stuff).to eq(:class_extension_stuff)
    end

    it "can override methods at runtime with a PrependedMethods submodule" do
      extension_mod = Module.new
      extension_mod.module_eval do
        def a_method
          :original_a_method
        end
      end
      extension_mod.const_set :PrependedMethods, Module.new
      extension_mod::PrependedMethods.module_eval do
        def a_method
          :extension_a_method
        end
      end

      subclass = create_model("prepends")
      subclass.add_extensions(extension_mod)

      expect(subclass.new.a_method).to eq(:extension_a_method)
    end
  end

  it "can create a schema even if it does exist" do
    expect(described_class).to_not be_schema_exists(:testing)
    described_class.create_schema(:testing)
    described_class.create_schema(:testing)
    expect(described_class).to be_schema_exists(:testing)
  end

  it "knows what its schema is named" do
    subclass = create_model([:testing, :a_table])
    expect(subclass.schema_name).to eq("testing")
  end

  it "knows that it doesn't belong to a schema if one hasn't been specified'" do
    subclass = create_model(:a_table)
    expect(subclass.schema_name).to be_nil
  end

  it "can build a single string of validation errors" do
    subclass = create_model(:the_constrained_table)

    obj = subclass.new
    obj.errors.add(:first_name, "is not present")
    obj.errors.add(:last_name, "is not present")
    obj.errors.add(:age, "is not an integer")

    expect(
      obj.error_messages,
    ).to eq("first_name is not present, last_name is not present, age is not an integer")
  end

  it "has a dataset to reduce expressions" do
    mc = Webhookdb::Postgres::TestingPixie
    x = mc.create(name: "Pixie X")
    y = mc.create(name: "Pixie Y")
    z = mc.create(name: "Pixie Z")
    ds = mc.dataset.reduce_expr(:|, [nil, Sequel[name: "Pixie X"], Sequel[name: "Pixie Z"], nil])
    expect(ds.all).to have_same_ids_as(x, z)

    ds = mc.dataset.reduce_expr(:&, [false, Sequel[name: "Pixie X"], Sequel[name: "Pixie Z"], nil])
    expect(ds.all).to be_empty

    ds = mc.dataset.reduce_expr(:|, [false, Sequel[name: "Pixie X"], Sequel[name: "Pixie Z"], nil], method: :exclude)
    expect(ds.all).to have_same_ids_as(y)

    ds = mc.dataset
    expect(ds.reduce_expr(:|, [nil, false], method: :exclude)).to equal(ds)
  end

  describe "#find_or_create_or_find" do
    let(:model_class) { Webhookdb::Postgres::TestingPixie }

    it "finds again if the create fails due to a race condition (UniqueConstraintViolation)" do
      name = "foo"
      placeholder = model_class.create(name: "not-" + name)
      expect(model_class).to receive(:find).with({name:}).twice do
        placeholder.name == name ? placeholder : nil
      end
      expect(model_class).to receive(:create).with({name:}) do
        placeholder.name = name
        raise Sequel::UniqueConstraintViolation
      end

      got = model_class.find_or_create_or_find(name:)
      expect(got).to_not be_nil
      expect(got).to be(placeholder)
    end

    it "can use a block with the call to create" do
      made = model_class.find_or_create_or_find(name: "foo") do |inst|
        inst.name = "bar"
      end
      expect(made.name).to eq("bar")
    end
  end

  context "async events", :async, db: :no_transaction do
    let(:instance) { Webhookdb::Postgres::TestingPixie.new }

    it "can immediately send an event prefixed with the sending model object" do
      instance.db.transaction do
        expect do
          instance.publish_immediate("wuz", 18)
        end.to publish("webhookdb.postgres.testingpixie.wuz", [18])
      end
    end

    it "can send an deferred event prefixed with the sending model object" do
      expect do
        instance.db.transaction do
          expect do
            instance.publish_deferred("deferred", "eighteen")
          end.to_not publish
        end
      end.to publish("webhookdb.postgres.testingpixie.deferred", ["eighteen"])
    end

    it "can immediately publish a deferred event if do_not_defer_events is set" do
      Webhookdb::Postgres.do_not_defer_events = true
      instance.db.transaction do
        expect do
          instance.publish_deferred("deferred")
          Webhookdb::Postgres.do_not_defer_events = false
        end.to publish("webhookdb.postgres.testingpixie.deferred")
      end
    end

    it "publishes a created event" do
      expect do
        instance.save_changes
      end.to publish("webhookdb.postgres.testingpixie.created", match([be_an(Integer), hash_including("id", "name")]))
    end

    it "publishes an updated event" do
      instance.set(name: "fire").save_changes
      expect do
        instance.update(name: "ice")
      end.to publish("webhookdb.postgres.testingpixie.updated", [instance.id, {"name" => ["fire", "ice"]}])
    end

    it "publishes a destroyed event" do
      instance.save_changes
      expect do
        instance.destroy
      end.to publish(
        "webhookdb.postgres.testingpixie.destroyed",
        include(
          instance.id,
          hash_including(
            "id" => instance.id,
            "name" => nil,
            "price_per_unit_cents" => 0,
            "price_per_unit_currency" => "USD",
          ),
        ),
      )
    end

    it "does not publish duplicate or redundant events" do
      matcher = publish("webhookdb.postgres.testingpixie.created")
      expect do
        instance.save_changes
        instance.update(name: "stone")
        instance.destroy
      end.to matcher
      expect(matcher.recorded_events.map(&:name)).to eq(
        [
          "webhookdb.postgres.testingpixie.created",
          "webhookdb.postgres.testingpixie.updated",
          "webhookdb.postgres.testingpixie.destroyed",
        ],
      )
    end

    it "converts all fields to native JSON types" do
      instance.active_during = Sequel::Postgres::PGRange.new(nil, nil, empty: true)
      instance.ip = IPAddr.new("1.2.3.4")
      instance.save_changes
      expect do
        instance.destroy
      end.to publish(
        "webhookdb.postgres.testingpixie.destroyed",
        include(
          instance.id,
          hash_including("active_during" => nil, "ip" => "1.2.3.4"),
        ),
      )
    end
  end

  describe "inspect" do
    it "uses symbol representation" do
      expect(Webhookdb::Role.create(name: "sam").inspect).to include(' name: "sam"')
    end

    it "formats timestamps in the local timezone" do
      inst = Webhookdb::Fixtures.customer.create
      inst.created_at = Time.new(2016, 12, 30, 22, 17, 55, "-00:00")
      s = Time.use_zone(ActiveSupport::TimeZone.new("Hawaii")) do
        inst.inspect
      end
      expect(s).to include("created_at: 2016-12-30 12:17:55")
    end

    it "omits empty fields" do
      inst = Webhookdb::Role.create(name: "foo")
      expect(inst.inspect).to include("name: ")
      inst.name = ""
      expect(inst.inspect).to_not include("name: ")
    end

    it "formats time ranges" do
      state = Webhookdb::Postgres::TestingPixie.create
      state.active_during_begin = Time.new(2016, 12, 30, 22, 17, 55, "-00:00")
      state.active_during_end = Time.new(2017, 12, 30, 22, 17, 55, "-00:00")

      s = Time.use_zone(ActiveSupport::TimeZone.new("Hawaii")) do
        state.inspect
      end
      expect(s).to include("active_during: [2016-12-30 12:17:55...2017-12-30 12:17:55)")
    end

    it "formats money" do
      state = Webhookdb::Postgres::TestingPixie.create
      state.price_per_unit_cents = 240
      expect(state.inspect).to include("price_per_unit: $2.40")
    end

    it "decrypts strings and uris" do
      st = Webhookdb::Fixtures.sync_target.postgres.create
      dbhost = URI(described_class.uri).host # do not hard-code localhost since we can be in a container
      expect(st.inspect).to include(%(connection_url: "postgres://*:*@#{dbhost}))
      st.connection_url = "definitely not a url"
      expect(st.inspect).to include('connection_url: "def...url')
      st.connection_url = "abc"
      expect(st.inspect).to include('connection_url: "...')
      st.connection_url = ""
      expect(st.inspect).to include('connection_url: "...')
    end

    it "abbreviates the text search column" do
      inst = Webhookdb::Fixtures.customer.create(name: "user", email: "a@bee.com")
      inst.text_search_reindex
      expect(inst.refresh.inspect).to include("text_search: {22}")
    end
  end

  describe "resource_lock!" do
    let(:instance) { Webhookdb::Fixtures.customer.create(note: "hello") }
    let(:now) { Time.now }

    it "raises a LockFailed if updated_at changed before/after the lock" do
      expect(instance).to receive(:updated_at).twice do
        now - rand
      end
      expect { instance.resource_lock! }.to raise_error(Webhookdb::LockFailed)
    end

    it "calls the block if updated_at is not set" do
      expect(instance).to have_attributes(updated_at: nil)
      expect(instance.resource_lock!(&:note)).to eq(instance.note)
    end

    it "calls the block if updated_at has not changed" do
      instance.update(updated_at: now.change(usec: 0))
      expect(instance.resource_lock!(&:note)).to eq(instance.note)
    end

    it "touches updated_at after the block returns" do
      expect { instance.resource_lock! { true } }.to(change(instance, :updated_at))
    end

    it "ignores fractional microseconds since databases do not store that precision" do
      instance.update(note: instance.note + "prime")
      expect(instance.refresh.updated_at.nsec).to eq(instance.refresh.updated_at.usec * 1000)
      instance.updated_at = instance.updated_at.change(nsec: (instance.updated_at.usec * 1000) + 1)
      expect(instance.resource_lock!(&:note)).to eq(instance.note)
    end
  end

  describe "lock?", db: :no_transaction do
    it "raises if the db is not in a transaction" do
      o = Webhookdb::Fixtures.customer.instance
      expect { o.lock? }.to raise_error(Webhookdb::LockFailed)
    end

    it "returns true if the lock is acquired" do
      o = Webhookdb::Fixtures.customer.create
      o.db.transaction do
        expect(o.lock?).to be(true)
        t = Thread.new do
          Sequel.connect(Webhookdb::Postgres::Model.uri) do |conn|
            got = conn.select(Sequel.lit("id FROM customers WHERE id = #{o.id} FOR UPDATE SKIP LOCKED")).all
            expect(got).to be_empty
          end
        end
        t.join
      end
    end

    it "returns false if the lock is not acquired" do
      o = Webhookdb::Fixtures.customer.create
      other_thread_took_lock = Concurrent::Event.new
      thread_can_finish_lock = Concurrent::Event.new
      t = Thread.new do
        Sequel.connect(Webhookdb::Postgres::Model.uri) do |conn|
          conn.transaction do
            conn << "SELECT * FROM customers WHERE id = #{o.id} FOR UPDATE NOWAIT"
            other_thread_took_lock.set
            thread_can_finish_lock.wait
          end
        end
      end
      other_thread_took_lock.wait
      o.db.transaction do
        expect(o.lock?).to be(false)
      end
      thread_can_finish_lock.set
      t.join
    ensure
      o.destroy
    end
  end

  describe "slow query logging" do
    before(:each) { @duration = described_class.db.log_warn_duration }

    after(:each) { described_class.db.log_warn_duration = @duration }

    it "logs slow queries with structure" do
      described_class.db.log_warn_duration = -1
      logs = capture_logs_from(described_class.logger, level: :warn, formatter: :json) do
        described_class.db.execute("SELECT 1=1")
      end
      expect(logs).to contain_exactly(
        include_json(
          message: eq("sequel_query"),
          duration_ms: be_positive,
          context: {
            query: eq("SELECT 1=1"),
          },
        ),
      )
    end

    it "does not try to parse messages that are not slow query logs" do
      logs = capture_logs_from(described_class.logger, level: :warn, formatter: :json) do
        described_class.logger.warn "hello there SELECT 1=1"
      end
      expect(logs).to have_a_line_matching(/"message":"hello there SELECT 1=1"/)
    end
  end

  describe "each_cursor_page" do
    names = ["a", "b", "c", "d"]
    cls = Webhookdb::Postgres::TestingPixie
    let(:ds) { cls.dataset }

    before(:each) do
      names.each { |n| cls.create(name: n) }
    end

    it "chunks pages and calls each item in the block" do
      result = []
      cls.each_cursor_page(page_size: 2) { |r| result << r.name }
      expect(result).to eq(names)
    end

    it "can order by a column" do
      result = []
      cls.each_cursor_page(page_size: 2, order: Sequel.desc(:name)) { |r| result << r.name }
      expect(result).to eq(names.reverse)
    end

    it "can order by multiple columns" do
      result = []
      cls.each_cursor_page(page_size: 2, order: [Sequel.desc(:name), :id]) { |r| result << r.name }
      expect(result).to eq(names.reverse)
    end

    it "can perform an action on the returned values of each chunk" do
      clean_ds = ds.exclude(Sequel.like(:name, "%prime")) # Avoid re-selecting the stuff we just inserted
      clean_ds.each_cursor_page_action(page_size: 3, action: ds.method(:multi_insert)) do |tp|
        {name: tp.name + "prime"}
      end
      expect(ds.order(:id).all.map(&:name)).to eq(
        ["a", "b", "c", "d", "aprime", "bprime", "cprime", "dprime"],
      )
    end

    it "can handle multiple return rows" do
      action_calls = 0
      action = lambda { |v|
        action_calls += 1
        ds.multi_insert(v)
      }
      cls.each_cursor_page_action(page_size: 3, action:) do |tp|
        tp.name == "a" ? (Array.new(10) { |i| {name: "a#{i}"} }) : nil
      end
      expect(ds.order(:id).all.map(&:name)).to eq(
        ["a", "b", "c", "d", "a0", "a1", "a2", "a3", "a4", "a5", "a6", "a7", "a8", "a9"],
      )
      expect(action_calls).to eq(2)
    end

    it "ignores nil results returned from the block" do
      cls.each_cursor_page_action(page_size: 1, action: ds.method(:multi_insert)) do |tp|
        tp.name >= "c" ? nil : {name: tp.name + "prime"}
      end
      expect(ds.order(:id).all.map(&:name)).to eq(
        ["a", "b", "c", "d", "aprime", "bprime"],
      )
    end
  end
end
