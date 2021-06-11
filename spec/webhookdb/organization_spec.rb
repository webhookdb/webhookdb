# frozen_string_literal: true

RSpec.describe "Webhookdb::Organization", :db do
  let(:described_class) { Webhookdb::Organization }

  describe "create_if_unique" do
    it "creates the org if it does not violate a unique constraint"
  end

  describe "prepare_database_connections" do
    let(:o) { Webhookdb::Fixtures.organization.create }

    after(:each) do
      o.remove_related_database
    end

    it "creates a randomly named database and connection strings" do
      o.prepare_database_connections
      expect(o.admin_connection_url).to(start_with("postgres://"))
      expect(o.readonly_connection_url).to(start_with("postgres://"))
    end

    it "scopes the admin connection permissions" do
      o.prepare_database_connections
      Sequel.connect(o.admin_connection_url) do |admin_conn|
        admin_conn << "CREATE TABLE my_test_table(val TEXT)"
        admin_conn << "INSERT INTO my_test_table (val) VALUES ('x')"
        rows = admin_conn.fetch("SELECT * FROM my_test_table").all
        expect(rows).to(eq([{val: "x"}]))
        admin_conn << "DROP TABLE my_test_table"
      end
    end

    it "scopes the readonly connection permissions" do
      o.prepare_database_connections

      Sequel.connect(o.admin_connection_url) do |admin_conn|
        Sequel.connect(o.readonly_connection_url) do |readonly_conn|
          expect do
            readonly_conn << "CREATE TABLE my_test_table(val TEXT)"
          end.to raise_error(Sequel::DatabaseError, /permission denied for schema public/)
          admin_conn << "CREATE TABLE my_test_table(val TEXT)"

          expect do
            readonly_conn << "INSERT INTO my_test_table (val) VALUES ('x')"
          end.to raise_error(Sequel::DatabaseError, /permission denied for table my_test_table/)
          admin_conn << "INSERT INTO my_test_table (val) VALUES ('x');"

          rows = readonly_conn.fetch("SELECT * FROM my_test_table").all
          expect(rows).to(eq([{val: "x"}]))

          expect do
            readonly_conn << "DROP TABLE my_test_table"
          end.to raise_error(Sequel::DatabaseError, /must be owner of table/)
          admin_conn << "DROP TABLE my_test_table"
        end
      end
    end

    it "errors if there are already database connections on the object"
  end

  describe "remove_related_database" do
    let(:o) { Webhookdb::Fixtures.organization.create }

    after(:each) do
      o.remove_related_database
    end

    it "removes the database and roles" do
      o.prepare_database_connections
      db_query = "SELECT count(1) FROM pg_database WHERE datistemplate = false AND datname = '#{o.dbname}'"
      user_query = "SELECT count(1) FROM pg_catalog.pg_user WHERE usename IN ('#{o.admin_user}', '#{o.readonly_user}')"
      expect(o.db.fetch(db_query).all).to(eq([{count: 1}]))
      expect(o.db.fetch(user_query).all).to(eq([{count: 2}]))
      o.remove_related_database
      expect(o.db.fetch(db_query).all).to(eq([{count: 0}]))
      expect(o.db.fetch(user_query).all).to(eq([{count: 0}]))
    end

    it "noops if connection urls are not set"
  end

  describe "validations" do
    it "requires all of the connections to be present, or none"
  end
end
