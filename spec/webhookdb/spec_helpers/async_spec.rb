# frozen_string_literal: true

require "webhookdb/spec_helpers/async"

RSpec.describe Webhookdb::SpecHelpers::Async, :sidekiq do
  describe "have_queue matcher", sidekiq: :fake do
    let(:cls) do
      Class.new do
        include Sidekiq::Worker
      end
    end

    before(:each) do
      stub_const("AsyncTestClass", cls)
    end

    it "can match a whole queue using consisting_of" do
      AsyncTestClass.perform_async(1)
      AsyncTestClass.perform_async(2)

      expect(Sidekiq).to have_queue("default").consisting_of(job_hash(cls, args: [1]), job_hash(cls, args: [2]))
      expect do
        expect(Sidekiq).to have_queue("default").consisting_of(job_hash(cls, args: [1]))
      end.to raise_error(/has size 2, expected 1/)
    end

    it "can match for inclusion of a single matcher" do
      AsyncTestClass.perform_async(1)
      AsyncTestClass.perform_async(2)
      AsyncTestClass.perform_async(3)

      expect(Sidekiq).to have_queue("default").including(job_hash(cls, args: [2]))
      expect do
        expect(Sidekiq).to have_queue("default").including(job_hash(cls, args: [4]))
      end.to raise_error(/failed to match Sidekiq queue default:/)
    end

    it "can match for a size" do
      AsyncTestClass.perform_async(1)
      AsyncTestClass.perform_async(2)

      expect(Sidekiq).to have_queue.of_size(2)
      expect do
        expect(Sidekiq).to have_queue.of_size(3)
      end.to raise_error(/has size 2, expected 3/)
    end

    it "can match for a name" do
      AsyncTestClass.perform_async(1)
      AsyncTestClass.perform_async(2)

      expect(Sidekiq).to have_queue.named("default")
      expect do
        expect(Sidekiq).to have_queue.named("default2")
      end.to raise_error(/match Sidekiq queue default2: is empty/)
    end
  end
end
