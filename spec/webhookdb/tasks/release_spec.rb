# frozen_string_literal: true

require "webhookdb/tasks"
require "webhookdb/tasks/release"
require "webhookdb/tasks/db"
require "webhookdb/tasks/sidekiq"

RSpec.describe Webhookdb::Tasks::Release do
  before(:all) do
    Webhookdb::Tasks::DB.new
    Webhookdb::Tasks::Sidekiq.new
    described_class.new
  end

  describe "release" do
    it "migrates the database, orgs, and marks the Sidekiq deployment" do
      Sidekiq.redis(&:flushdb)
      stub_const("Webhookdb::RELEASE", "fakerelease")
      marks = Timecop.freeze("2025-02-15T12:00:00Z") do
        Rake::Task["release"].invoke
        Sidekiq::Deploy.new.fetch
      end
      expect(marks).to eq({"2025-02-15T12:00:00Z" => "fakerelease"})
    end
  end
end
