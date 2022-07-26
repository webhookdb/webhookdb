# frozen_string_literal: true

require "concurrent"

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

  after(:each) do
    instance.force_disconnect_all
  end

  def change_db(url, name)
    u = URI(url)
    u.path = name
    return u.to_s
  end

  def capture_conn(inst, url, **kw)
    c = nil
    inst.borrow(url, **kw) do |co|
      c = co
    end
    return c
  end

  describe "borrow" do
    it "errors if url is blank or block is not given" do
      expect { instance.borrow("") {} }.to raise_error(ArgumentError, /url cannot/)
      expect { instance.borrow("postgres://x/b") }.to raise_error(LocalJumpError)
    end

    it "errors if being called recursively with the same url" do
      expect do
        instance.borrow(db1_url) do
          instance.borrow(db2_url) {}
        end
      end.to_not raise_error

      expect do
        instance.borrow(db1_url) do
          instance.borrow(db1_url) {}
        end
      end.to raise_error(described_class::ReentranceError)
    end

    it "reuses available connections" do
      c1 = capture_conn(instance, db1_url)
      c2 = capture_conn(instance, db1_url)
      expect(c1).to be c2
    end

    it "creates new connections as needed" do
      eventouter = Concurrent::Event.new
      eventinner = Concurrent::Event.new
      c1, c2, = nil
      Thread.new do
        instance.borrow(db1_url, timeout: 5) do |c1c|
          c1 = c1c
          expect(c1.fetch("show statement_timeout").all.first[:statement_timeout]).to start_with("5")
          Thread.new do
            instance.borrow(db1_url, timeout: 7) do |c2c|
              c2 = c2c
              expect(c2.fetch("show statement_timeout").all.first[:statement_timeout]).to start_with("7")
            end
            eventinner.set
          end
          eventinner.wait
          expect(c1.fetch("show statement_timeout").all.first[:statement_timeout]).to start_with("5")
        end
        eventouter.set
      end
      eventouter.wait
      expect(c1).to_not be(c2)
    end

    it "can reuse connections across threads" do
      event = Concurrent::Event.new
      instance.borrow(db1_url) do |c|
        c << "create table reusetest(x text)"
      end
      Thread.new do
        instance.borrow(db1_url) do |c|
          c << "insert into reusetest(x) values ('a')"
        end
        event.set
      end
      event.wait
      instance.borrow(db1_url) do |c|
        expect(c[:reusetest].all).to have_length(1)
      end
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
        expect(instance.dbs_for_urls).to have_length(1)
        instance.borrow(db2_url) do |_|
          expect(instance.dbs_for_urls).to have_length(2)
          instance.borrow(db3_url) do |_|
            expect(instance.dbs_for_urls).to have_length(3)
          end
          expect(instance.dbs_for_urls).to have_length(3)
        end
      end
    end

    it "prunes available connections once it has been prune_seconds since the last prune" do
      Timecop.freeze do
        instance.borrow(db1_url) do |_|
          # Borrow two additional conns. No time has elapsed, so we will not prune either.
          instance.borrow(db2_url) { |_| }
          instance.borrow(db3_url) { |_| }
          expect(instance.summarize).to include(
            db1_url => {available: 0, loaned: 1},
            db2_url => {available: 1, loaned: 0},
            db3_url => {available: 1, loaned: 0},
          )
          # Move forward. When we borrow one url, the other idle one is trimmed.
          Timecop.freeze(5.minutes.from_now)
          instance.borrow(db2_url) { |_| }
          expect(instance.summarize).to include(
            db1_url => {available: 0, loaned: 1},
            db2_url => {available: 1, loaned: 0},
          )
          # Re-borrow the other URL. Since we just pruned, it won't run the algo again.
          instance.borrow(db3_url) { |_| }
          expect(instance.summarize).to include(
            db1_url => {available: 0, loaned: 1},
            db2_url => {available: 1, loaned: 0},
            db3_url => {available: 1, loaned: 0},
          )
          # But now move forward; again, the other URL is trimmed
          Timecop.freeze(5.minutes.from_now)
          instance.borrow(db3_url) { |_| }
          expect(instance.summarize).to include(
            db1_url => {available: 0, loaned: 1},
            db3_url => {available: 1, loaned: 0},
          )
          # Ensure that we don't trim anything with no available entries and an outstanding loan
          Timecop.freeze(5.minutes.from_now)
          instance.borrow(db2_url) do |_|
            expect(instance.summarize).to include(
              db1_url => {available: 0, loaned: 1},
              db2_url => {available: 0, loaned: 1},
            )
          end
        end
      end
    end

    describe "transaction handling" do
      it "does not issue transactions by default" do
        c = capture_conn(instance, db1_url)
        expect(c).to_not receive(:<<)
        instance.borrow(db1_url) { |_| }
      end

      it "does not issue a rollback if transactions are not enabled" do
        c = capture_conn(instance, db1_url)
        expect(c).to_not receive(:<<)
        expect do
          instance.borrow(db1_url) { |_| raise NotImplementedError }
        end.to raise_error(NotImplementedError)
      end

      it "can wrap the block in a transaction (test via spy)" do
        c = capture_conn(instance, db1_url)
        expect(c).to receive(:<<).with("BEGIN;")
        expect(c).to receive(:<<).with("COMMIT;")
        instance.borrow(db1_url, transaction: true) { |_| }
      end

      it "can wrap the block in a transaction (test via behavior)" do
        # TODO: run another thread to observe the transaction has not committed
        instance.borrow(db1_url, transaction: true) do |c|
          c << "CREATE TABLE t1(c text)"
        end
        instance.borrow(db1_url, transaction: true) do |c|
          c << "insert into t1(c) values('x')"
        end
      end

      it "rolls back on failure (test via spy)" do
        c = capture_conn(instance, db1_url)
        expect(c).to receive(:<<).with("BEGIN;")
        expect(c).to receive(:<<).with("select 1/0;").and_raise(Sequel::DatabaseError)
        expect(c).to receive(:<<).with("ROLLBACK;")
        expect do
          instance.borrow(db1_url, transaction: true) do |c1|
            c1 << "select 1/0;"
          end
        end.to raise_error(Sequel::DatabaseError)
      end

      it "rolls back on failure (test via behavior)" do
        expect do
          instance.borrow(db1_url, transaction: true) do |c|
            c << "CREATE TABLE rollbacktest(c text)"
            c << "select 1/0"
          end
        end.to raise_error(Sequel::DatabaseError)
        expect do
          instance.borrow(db1_url, transaction: true) do |c|
            c << "CREATE TABLE rollbacktest(c text)"
            c << "insert into rollbacktest(c) values('x')"
          end
        end.to_not raise_error
      end
    end

    describe "timeouts" do
      it "can use a known :timeout option" do
        conn = capture_conn(instance, db1_url)
        expect(conn).to receive(:<<).with("SET statement_timeout TO 30000")
        expect(conn).to receive(:<<).with("SET statement_timeout TO 0")
        instance.borrow(db1_url, timeout: :fast) do |c|
          expect(c).to be conn
        end
      end

      it "does not modify statement timeout if not given" do
        conn = capture_conn(instance, db1_url)
        expect(conn).to_not receive(:<<)
        instance.borrow(db1_url, timeout: nil) do |c|
          expect(c).to be conn
        end
      end

      it "errors if :timeout is unknown" do
        expect do
          instance.borrow(db1_url, timeout: :foo) {}
        end.to raise_error(/no timeout accessor :timeout_foo/)
      end

      it "uses a numeric timeout as the timeout seconds" do
        conn = capture_conn(instance, db1_url)
        expect(conn).to receive(:<<).with("SET statement_timeout TO 5000")
        expect(conn).to receive(:<<).with("SET statement_timeout TO 0")
        instance.borrow(db1_url, timeout: 5) do |c|
          expect(c).to be conn
        end
      end

      it "reverts the timeout on error" do
        conn = capture_conn(instance, db1_url)
        expect(conn).to receive(:<<).with("SET statement_timeout TO 5000")
        expect(conn).to receive(:<<).with("SET statement_timeout TO 0")
        expect do
          instance.borrow(db1_url, timeout: 5) do |_|
            raise NotImplementedError
          end
        end.to raise_error(NotImplementedError)
      end
    end
  end

  describe "disconnect" do
    it "disconnects the connection for the given url" do
      instance.borrow(db1_url) {}
      expect(instance.dbs_for_urls).to have_length(1)
      instance.disconnect(db1_url)
      expect(instance.dbs_for_urls).to be_empty
    end

    it "noops if there is no borrowed connection" do
      expect(instance.dbs_for_urls).to be_empty
      instance.disconnect(db1_url)
      expect(instance.dbs_for_urls).to be_empty
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

  describe "force_disconnect_all" do
    it "disconnects all open connections and clears them from the cache" do
      conn = capture_conn(instance, db1_url)
      expect(conn).to receive(:disconnect).and_call_original
      expect(instance.dbs_for_urls).to have_length(1)
      instance.force_disconnect_all
      expect(instance.dbs_for_urls).to be_empty
    end
  end
end
