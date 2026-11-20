# frozen_string_literal: true

require "sequel"
require "sequel/text_searchable"

RSpec.describe "sequel-text-searchable" do
  before(:all) do
    dburl = ENV.fetch("DATABASE_URL", nil)
    @db = Sequel.connect(dburl)
    @db.drop_table?(:sts_tester)
    @db.create_table(:sts_tester) do
      primary_key :id
      text :name
      text :desc
      integer :parent_id
      tsvector :text_search
    end
    SequelTextSearchable.index_mode = :off
  end

  after(:all) do
    @db.disconnect
    SequelTextSearchable.index_mode = :off
  end

  before(:each) do
    @db[:sts_tester].truncate
  end

  let(:model) do
    m = Class.new(Sequel::Model(:sts_tester)) do
      plugin :dirty
      plugin :text_searchable
      many_to_one :parent, class: self
      def text_search_terms = [[self.name, "A"], self.desc, self.parent]
    end
    m.dataset = @db[:sts_tester]
    m
  end

  describe "configuration" do
    it "errors if the dirty plugin is not loaded" do
      expect do
        Class.new(Sequel::Model(:sts_tester)) do
          plugin :text_searchable
        end
      end.to raise_error(/:dirty plugin must be loaded first/)
    end

    it "errors for an invalid index model" do
      expect do
        SequelTextSearchable.index_mode = :x
      end.to raise_error(/must be one of/)
    end

    it "can define custom options" do
      m = Class.new(Sequel::Model(:sts_tester)) do
        plugin :dirty
        plugin :text_searchable, column: :mycol, search_options: {x: 1}
      end
      expect(m.text_search_column).to eq(:mycol)
      expect(m.text_search_options).to eq({x: 1})
    end

    it "can use a shortcut for terms" do
      m = Class.new(Sequel::Model(:sts_tester)) do
        plugin :dirty
        plugin :text_searchable, terms: [:name, [:desc, "B"]]
      end
      m.dataset = @db[:sts_tester]
      o = m.new(name: "hi")
      expect(o.text_search_terms).to eq(["hi", [nil, "B"]])
    end

    it "errors if text_search_terms is not defined or passed" do
      m = Class.new(Sequel::Model(:sts_tester)) do
        plugin :dirty
        plugin :text_searchable
      end
      o = m.new
      expect { o.text_search_terms }.to raise_error(NotImplementedError)
    end
  end

  it "indexes after save and can search" do
    geralt = model.create(name: "Geralt", desc: "Rivia")
    ciri = model.create(name: "Rivia", desc: "Ciri")
    model.text_search_reindex_all

    expect(model.dataset.text_search("geralt").all).to have_same_ids_as(geralt)
    expect(model.dataset.text_search("rivia").all).to have_same_ids_as(geralt, ciri)
    ciri.update(name: "Ciri")
    model.text_search_reindex_model(ciri.pk)
    expect(model.dataset.text_search("rivia").all).to have_same_ids_as(geralt)
  end

  describe "indexing" do
    before(:each) do
      SequelTextSearchable.index_mode = :sync
    end

    it "happens after create" do
      geralt = model.create(name: "Geralt", desc: "Rivia")
      expect(model.dataset.text_search("geralt").all).to have_same_ids_as(geralt)
    end

    it "happens after update" do
      geralt = model.create(name: "Geralt", desc: "Rivia")
      expect(geralt).to receive(:text_search_reindex).and_call_original
      geralt.update(name: "Ciri")
      expect(model.dataset.text_search("ciri").all).to have_same_ids_as(geralt)
    end

    describe "using :terms in configuration" do
      it "does not index if term columns are unchanged" do
        model = Class.new(Sequel::Model(:sts_tester)) do
          plugin :dirty
          plugin :text_searchable, terms: [:name]
        end
        model.dataset = @db[:sts_tester]

        geralt = model.create(name: "Geralt", desc: "Rivia")
        geralt.update(name: "Ciri")
        expect(model.dataset.text_search("ciri").all).to have_same_ids_as(geralt)

        expect(geralt).to_not receive(:text_search_reindex)
        geralt.update(name: "Ciri") # No change
        geralt.update(desc: "Cintra") # Not a term
      end
    end

    describe "with a custom text_search_terms method" do
      it "always indexes" do
        m = Class.new(Sequel::Model(:sts_tester)) do
          plugin :dirty
          plugin :text_searchable
          def text_search_terms = [[self.name, "A"]]
        end
        m.dataset = @db[:sts_tester]

        geralt = model.create(name: "Geralt", desc: "Rivia")
        expect(geralt).to receive(:text_search_reindex).twice.and_call_original
        geralt.update(name: "Ciri")
        # rubocop:disable Sequel/SaveChanges
        geralt.save
        # rubocop:enable Sequel/SaveChanges
        expect(model.dataset.text_search("ciri").all).to have_same_ids_as(geralt)
      end
    end
  end

  def getvector
    return @db[:sts_tester].order(:id).select(:text_search).all.map { |row| row[:text_search] }.first
  end

  describe "index_mode" do
    it "does not index when :off" do
      SequelTextSearchable.index_mode = :off
      model.create(name: "ciri")
      expect(getvector).to be_nil
    end

    it "indexes when :sync" do
      SequelTextSearchable.index_mode = :sync
      model.create(name: "ciri")
      expect(getvector).to eq("'ciri':1A")
    end

    it "indexes in a pool when :async" do
      SequelTextSearchable.index_mode = :async
      model.create(name: "ciri")
      SequelTextSearchable.threadpool.shutdown
      SequelTextSearchable.threadpool.wait_for_termination
      expect(getvector).to eq("'ciri':1A")
    end
  end

  describe "text_search_terms" do
    it "calculates the tsvector properly based on all terms" do
      c1 = model.create(name: "Ciri")
      c1.text_search_reindex
      expect(getvector).to eq("'ciri':1A")

      c1.update(desc: "'witcher")
      c1.text_search_reindex
      expect(getvector).to eq("'ciri':1A 'witcher':2")

      c1.update(parent: model.create(desc: "geralt"))
      c1.text_search_reindex
      expect(getvector).to eq("'ciri':1A 'geralt':3 'witcher':2")

      c1.parent.define_singleton_method(:text_search_terms_for_related) { ["princess"] }
      c1.text_search_reindex
      expect(getvector).to eq("'ciri':1A 'princess':3 'witcher':2")
    end

    it "flattens deeply nested terms, removing parent ranks" do
      gp = model.create(name: "grandparent")
      p = model.create(name: "parent", parent: gp)
      c = model.create(name: "child", parent: p)
      gc = model.create(name: "grandchild", parent: c)
      model.text_search_reindex_all
      expect(gp.refresh).to have_attributes(text_search: "'grandpar':1A")
      expect(p.refresh).to have_attributes(text_search: "'grandpar':2 'parent':1A")
      expect(c.refresh).to have_attributes(text_search: "'child':1A 'grandpar':3 'parent':2")
      expect(gc.refresh).to have_attributes(text_search: "'child':2 'grandchild':1A 'grandpar':4 'parent':3")
    end

    it "handles hashes instead of strings and tuples" do
      c1 = model.create(name: "Ciri")
      c1.define_singleton_method(:text_search_terms) { [{"ciri" => "B"}, {"geralt" => "C"}] }
      c1.text_search_reindex
      expect(getvector).to eq("'ciri':1B 'geralt':2C")

      c1.define_singleton_method(:text_search_terms) { {"ciri" => "A", "geralt" => "C"} }
      c1.text_search_reindex
      expect(getvector).to eq("'ciri':1A 'geralt':2C")
    end
  end

  describe "reindexing" do
    it "can reindex all subclasses" do
      SequelTextSearchable.index_mode = :sync
      m1 = Class.new(Sequel::Model(:sts_tester)) do
        plugin :dirty
        plugin :text_searchable, terms: [:name]
      end
      m1.dataset = @db[:sts_tester]
      m2 = Class.new(Sequel::Model(:sts_tester)) do
        plugin :dirty
        plugin :text_searchable, terms: [:name]
      end
      m2.dataset = @db[:sts_tester]
      m1.create(name: "x")
      m2.create(name: "y")
      expect(@db[:sts_tester].where(text_search: nil).all).to be_empty
      @db[:sts_tester].update(text_search: nil)
      expect(@db[:sts_tester].where(text_search: nil).all).to have_length(2)
      SequelTextSearchable.reindex_all
      expect(@db[:sts_tester].where(text_search: nil).all).to be_empty
    end
  end
end
