# frozen_string_literal: true

RSpec.describe Webhookdb::Backfiller, :db do
  fake_class = Class.new(described_class) do
    attr_reader :handled, :fetched

    def initialize(pages: nil, on_fetch: nil)
      @handled = []
      @fetched = []
      @pages = pages
      @on_fetch = on_fetch
      super()
    end

    def handle_item(item)
      self.handled << item
    end

    def fetch_backfill_page(*args)
      self.fetched << args
      return @on_fetch[*args] if @on_fetch
      return @pages[self.fetched.size - 1] if @pages
      return [], nil
    end
  end

  it "can fetch once" do
    bf = fake_class.new
    bf.backfill(nil)
    expect(bf.fetched).to eq([[nil, {last_backfilled: nil}]])
    expect(bf.handled).to be_empty
  end

  it "fetches until no token is returned" do
    bf = fake_class.new(pages: [[[1], "a"], [[2], "b"], [[3, 4], nil]])
    bf.backfill(nil)
    expect(bf.fetched).to eq([[nil, {last_backfilled: nil}], ["a", {last_backfilled: nil}],
                              ["b", {last_backfilled: nil}],])
    expect(bf.handled).to eq([1, 2, 3, 4])
  end

  describe "with bulk", :fake_replicator do
    let(:sint) { Webhookdb::Fixtures.service_integration.create }
    let(:backfiller_cls) do
      Class.new(Webhookdb::Backfiller) do
        include Webhookdb::Backfiller::Bulk
        attr_reader :fetched

        def initialize(sint, pages, conditional_upsert: false, page_size: 2)
          @sint = sint
          @pages = pages
          @fetched = []
          @conditional_upsert = conditional_upsert
          @page_size = page_size
          super()
        end

        def conditional_upsert? = @conditional_upsert
        def upsert_page_size = @page_size
        def prepare_body(_body) = nil
        define_method(:upserting_replicator) { @sint.replicator }
        def fetch_backfill_page(*args)
          @fetched << args
          return @pages[self.fetched.size - 1]
        end
      end
    end

    before(:each) do
      sint.organization.prepare_database_connections
      sint.replicator.create_table
    end

    after(:each) do
      sint.organization.remove_related_database
    end

    def body(id)
      return {"my_id" => id, "at" => "Thu, 30 Jul 2016 21:12:33 +0000"}
    end

    it "flushes pending inserts if backfill is bulk" do
      bf = backfiller_cls.new(
        sint,
        [
          [[body("1")], "a"],
          [[body("2"), body("3"), body("4")], "b"],
          [[body("5")], nil],
        ],
      )
      bf.backfill(nil)
      expect(bf.fetched).to eq(
        [[nil, {last_backfilled: nil}], ["a", {last_backfilled: nil}], ["b", {last_backfilled: nil}]],
      )
      expect(sint.replicator.readonly_dataset(&:all)).to have_length(5)
    end

    it "ignores items that are not upserted by the replicator" do
      Webhookdb::Replicator::Fake.resource_and_event_hook = lambda { |r|
        r.body.fetch("my_id") == "3" ? [nil, nil] : [r.body, nil]
      }
      bf = backfiller_cls.new(
        sint,
        [
          [[body("2"), body("3"), body("4")], nil],
        ],
      )
      bf.backfill(nil)
      expect(sint.replicator.readonly_dataset(&:all)).to have_length(2)
    end

    describe "conditional upserting" do
      let(:pages) do
        [
          [[{"my_id" => "x", "v" => 1, "at" => "Thu, 30 Jul 2016 21:12:33 +0000"}], "a"],
          [[{"my_id" => "x", "v" => 2, "at" => "Thu, 30 Jul 2016 21:12:33 +0000"}], nil],
        ]
      end

      it "is used if enabled" do
        bf = backfiller_cls.new(
          sint,
          pages,
          conditional_upsert: true,
          page_size: 1,
        )
        bf.backfill(nil)
        expect(sint.replicator.readonly_dataset(&:all)).to contain_exactly(
          include(data: hash_including("v" => 1)),
        )
      end

      it "is not used if not enabled" do
        bf = backfiller_cls.new(
          sint,
          pages,
          conditional_upsert: false,
          page_size: 1,
        )
        bf.backfill(nil)
        expect(sint.replicator.readonly_dataset(&:all)).to contain_exactly(
          include(data: hash_including("v" => 2)),
        )
      end
    end
  end
end
