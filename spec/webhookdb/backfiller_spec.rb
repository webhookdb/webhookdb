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

  describe "with bulk" do
    let(:sint) { Webhookdb::Fixtures.service_integration.create }

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
      cls = Class.new(Webhookdb::Backfiller) do
        include Webhookdb::Backfiller::Bulk
        attr_reader :fetched

        def initialize(sint, pages)
          @sint = sint
          @pages = pages
          @fetched = []
          super()
        end

        def upsert_page_size = 2
        def prepare_body(_body) = nil
        define_method(:upserting_replicator) { @sint.replicator }
        def fetch_backfill_page(*args)
          @fetched << args
          return @pages[self.fetched.size - 1]
        end
      end
      bf = cls.new(
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
  end
end
