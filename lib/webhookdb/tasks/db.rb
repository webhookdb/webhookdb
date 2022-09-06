# frozen_string_literal: true

require "rake/tasklib"
require "sequel"

require "webhookdb"
require "webhookdb/postgres"

module Webhookdb::Tasks
  class DB < Rake::TaskLib
    def initialize
      super()
      namespace :db do
        desc "Drop all tables in the public schema."
        task :drop_tables do
          require "webhookdb/postgres"
          Webhookdb::Postgres.load_superclasses
          Webhookdb::Postgres.each_model_superclass do |sc|
            sc.db[:pg_tables].where(schemaname: "public").each do |tbl|
              self.exec(sc.db, "DROP TABLE #{tbl[:tablename]} CASCADE")
            end
          end
        end

        desc "Remove all data from application schemas"
        task :wipe do
          require "webhookdb/postgres"
          Webhookdb::Postgres.load_superclasses
          Webhookdb::Postgres.each_model_class do |c|
            c.truncate(cascade: true)
          end
        end

        desc "Run migrations (rake db:migrate[<target>] to go to a specific version)"
        task :migrate, [:version] do |_, args|
          require "webhookdb/postgres"
          Webhookdb::Postgres.load_superclasses
          Webhookdb::Postgres.run_all_migrations(target: args[:version]&.to_i)
        end

        desc "Re-create the database tables. Drop tables and migrate."
        task reset: ["db:drop_tables", "db:migrate"]

        task :drop_replication_databases do
          require "webhookdb/postgres"
          Webhookdb::Postgres.load_superclasses
          Webhookdb::Postgres.each_model_superclass do |c|
            c.db[:pg_database].grep(:datname, "adb%").select(:datname).all.each do |row|
              c.db << "DROP DATABASE #{row[:datname]}"
            end
          end
        end

        task drop_tables_and_replication_databases: ["db:drop_tables", "db:drop_replication_databases"]

        task wipe_tables_and_drop_replication_databases: ["db:wipe", "db:drop_replication_databases"]

        task :lookup_org_admin_url, [:org_id] do |_, args|
          (orgid = args[:org_id]) or raise "Must provide org id as first argument"
          require "webhookdb"
          Webhookdb.load_app
          org_cond = orgid.match?(/^\d$/) ? orgid.to_i : {key: orgid}
          (org = Webhookdb::Organization[org_cond]) or raise "Org #{orgid} does not exist"
          u = org.admin_connection_url
          raise "Org #{orgid} has no connection url yet" if u.blank?
          print(u)
        end
      end
    end

    def exec(db, cmd)
      print cmd
      begin
        db.execute(cmd)
        print "\n"
      rescue StandardError
        print " (error)\n"
        raise
      end
    end
  end
end
