# frozen_string_literal: true

require "webhookdb/tasks"
require "webhookdb/tasks/sidekiq"

RSpec.describe Webhookdb::Tasks::Sidekiq, sidekiq: :disable do
  before(:all) do
    described_class.new
  end

  describe "reset" do
    it "clears the redis DB" do
      Sidekiq.redis { |c| c.set("testkey", "1") }
      expect(Sidekiq.redis { |c| c.get("testkey") }).to eq("1")
      Rake::Task["sidekiq:reset"].invoke
      expect(Sidekiq.redis { |c| c.get("testkey") }).to be_nil
    end
  end

  describe "retry_all" do
    it "enqueues all retry set jobs for retry" do
      # Tested for coverage, sorry.
      Rake::Task["sidekiq:retry_all"].invoke
      expect(Sidekiq::RetrySet.new.size).to eq(0)
    end
  end

  describe "retry_all_dead" do
    it "enqueues all dead set jobs for retry" do
      # Tested for coverage, sorry.
      Rake::Task["sidekiq:retry_all_dead"].invoke
      expect(Sidekiq::DeadSet.new.size).to eq(0)
    end
  end
end
