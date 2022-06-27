# frozen_string_literal: true

RSpec.describe Webhookdb::ConnectionCache do
  let(:instance) { described_class.new(prune_interval: 120.seconds) }
  let(:superuser_url) { @superuser_url }
  let(:db1_url) { @db1_url }
  let(:db2_url) { @db2_url }
  let(:db3_url) { @db3_url }
  let(:current_db) { Sequel.lit("current_database() as db") }

  before(:all) do
    @superuser_url = Webhookdb::Postgres::Model.uri
    @db1_url = change_db(@superuser_url, "/db1")
    @db2_url = change_db(@superuser_url, "/db2")
    @db3_url = change_db(@superuser_url, "/db3")
    Sequel.connect(@superuser_url) do |db|
      ["db1", "db2", "db3"].each do |name|
        db << "DROP DATABASE IF EXISTS #{name}"
        db << "CREATE DATABASE #{name}"
      end
    end
  end

  def change_db(url, name)
    u = URI(url)
    u.path = name
    return u.to_s
  end

  describe "borrow" do
    it "errors if url is blank or block is not given" do
      expect { instance.borrow("") {} }.to raise_error(ArgumentError, /url cannot/)
      expect { instance.borrow("postgres://x/b") }.to raise_error(LocalJumpError)
    end

    it "returns the result of the block" do
      got = instance.borrow(db1_url) do |db|
        db.select(current_db).all
      end
      expect(got).to eq([{db: "db1"}])

      got = instance.borrow(db2_url) do |db|
        db.select(current_db).all
      end
      expect(got).to eq([{db: "db2"}])
    end

    it "only opens a connection when a connection for a new host is borrowed" do
      instance.borrow(db1_url) do |_|
        expect(instance.databases).to have_length(1)
        instance.borrow(db1_url) do |_|
          expect(instance.databases).to have_length(1)
        end
        instance.borrow(db2_url) do |_|
          expect(instance.databases).to have_length(2)
          instance.borrow(db3_url) do |_|
            expect(instance.databases).to have_length(3)
          end
          expect(instance.databases).to have_length(3)
        end
      end
    end

    it "prunes connections with zero borrows once it has been prune_seconds since the last prune" do
      Timecop.freeze do
        instance.borrow(db1_url) do |_|
          # Borrow two additional conns. No time has elapsed, so we will not prune either.
          instance.borrow(db2_url) { |_| }
          instance.borrow(db3_url) { |_| }
          expect(instance.databases.keys).to contain_exactly(db1_url, db2_url, db3_url)
          # Move forward. When we borrow one url, the other idle one is trimmed.
          Timecop.freeze(5.minutes.from_now)
          instance.borrow(db2_url) { |_| }
          expect(instance.databases.keys).to contain_exactly(db1_url, db2_url)
          # Re-borrow the other URL. Since we just pruned, it won't run the algo again.
          instance.borrow(db3_url) { |_| }
          expect(instance.databases.keys).to contain_exactly(db1_url, db2_url, db3_url)
          # But now move forward; again, the other URL is trimmed
          Timecop.freeze(5.minutes.from_now)
          instance.borrow(db3_url) { |_| }
          expect(instance.databases.keys).to contain_exactly(db1_url, db3_url)
        end
      end
    end
  end

  describe "disconnect" do
    it "disconnects the connection for the given url" do
      instance.borrow(db1_url) {}
      expect(instance.databases).to have_length(1)
      instance.disconnect(db1_url)
      expect(instance.databases).to be_empty
    end

    it "noops if there is no borrowed connection" do
      expect(instance.databases).to be_empty
      instance.disconnect(db1_url)
      expect(instance.databases).to be_empty
    end

    it "errors of an empty url" do
      expect do
        instance.disconnect("")
      end.to raise_error(ArgumentError, "url cannot be blank")
    end

    it "errors if there are pending connections" do
      instance.borrow(db1_url) do
        expect do
          instance.disconnect(db1_url)
        end.to raise_error(Webhookdb::InvalidPrecondition, /still has/)
      end
    end
  end
end
