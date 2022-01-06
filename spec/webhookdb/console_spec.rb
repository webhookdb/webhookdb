# frozen_string_literal: true

require "webhookdb/console"

RSpec.describe Webhookdb::Console, :db do
  describe "safe mode" do
    before(:all) do
      described_class.enable_safe_mode
    end

    after(:all) do
      described_class.disable_safe_mode
    end

    let(:model) { Webhookdb::Postgres::TestingPixie }
    let(:dataset) { model.dataset }
    let(:instance) { model.create }

    describe "unsafe" do
      it "raises if unsafe is not given a block" do
        expect { described_class.unsafe }.to raise_error(LocalJumpError, /must be called with a block/)
      end

      it "returns the value fo the block" do
        expect(described_class.unsafe { 5 }).to eq(5)
      end
    end

    context "with no unsafe block" do
      it "allows selects" do
        expect { dataset.all }.to_not raise_error
      end

      it "allows updates with a WHERE" do
        expect { dataset.where(id: instance.id).update(name: "newname") }.to_not raise_error
        expect { instance.update(name: "newername") }.to_not raise_error
      end

      it "forbids updates without a WHERE" do
        expect { dataset.update(name: "newname") }.to raise_error(Webhookdb::Console::ForbiddenOperation)
      end

      it "treats DELETE with a WHERE as unsafe" do
        expect { instance.destroy }.to raise_error(Webhookdb::Console::UnsafeOperation)
        expect { dataset.destroy }.to raise_error(Webhookdb::Console::UnsafeOperation)
        expect { dataset.where(id: 0).delete }.to raise_error(Webhookdb::Console::UnsafeOperation)
      end

      it "forbids DELETE without a WHERE" do
        expect { dataset.delete }.to raise_error(Webhookdb::Console::ForbiddenOperation)
      end

      it "forbids TRUNCATE" do
        expect { dataset.truncate }.to raise_error(Webhookdb::Console::ForbiddenOperation)
      end
    end

    context "with an unsafe block" do
      around(:each) do |example|
        described_class.unsafe do
          example.run
        end
      end

      it "forbids updates without a WHERE" do
        expect { dataset.update(name: "newname") }.to raise_error(Webhookdb::Console::ForbiddenOperation)
      end

      it "allows DELETE with a WHERE" do
        expect { instance.destroy }.to_not raise_error
        model.create
        expect { dataset.destroy }.to_not raise_error
        expect { dataset.where(id: 0).delete }.to_not raise_error
      end

      it "forbids DELETE without a WHERE" do
        expect { dataset.delete }.to raise_error(Webhookdb::Console::ForbiddenOperation)
      end
    end
  end
end
