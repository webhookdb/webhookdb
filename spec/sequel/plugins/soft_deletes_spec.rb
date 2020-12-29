# frozen_string_literal: true

require "sequel/plugins/soft_deletes"

RSpec.describe Sequel::Plugins::SoftDeletes, :db do
  let(:table_name) { :soft_deletes_test }

  it "sets the soft-delete column to :soft_deleted_at if none is specified" do
    model_class = create_model(table_name)
    model_class.plugin(:soft_deletes)
    expect(model_class.soft_delete_column).to eq(:soft_deleted_at)
  end

  it "allows the class to override the soft-delete column" do
    model_class = create_model(table_name)
    model_class.plugin(:soft_deletes, column: :deleted_at)
    expect(model_class.soft_delete_column).to eq(:deleted_at)
  end

  it "defines a #soft_delete method on extended model instances" do
    model_class = create_model(table_name)
    model_class.plugin(:soft_deletes)
    instance = model_class.new

    expect(instance).to respond_to(:soft_delete)
  end

  context "extended model classes with a timestamp soft-delete column" do
    let(:model_class) do
      mc = create_model(table_name) do
        primary_key :id
        timestamp :deleted_at
      end
      mc.plugin(:soft_deletes, column: :deleted_at)
      mc
    end

    it "sets its column to 'now' when soft-deleted" do
      instance = model_class.create
      instance.soft_delete
      expect(instance.deleted_at).to be_a(Time)
      expect(instance.deleted_at).to be_within(5.seconds).of(Time.now)
    end

    it "sets up a subset for selecting (or de-selecting) soft-deleted rows" do
      expect(model_class.dataset.soft_deleted).to be_a(Sequel::Dataset)
      expect(model_class.dataset.not_soft_deleted).to be_a(Sequel::Dataset)

      instance = model_class.create
      expect(model_class.dataset.soft_deleted.all).not_to include(instance)
      expect(model_class.dataset.not_soft_deleted.all).to include(instance)

      instance.soft_delete
      expect(model_class.dataset.soft_deleted.all).to include(instance)
      expect(model_class.dataset.not_soft_deleted.all).not_to include(instance)
    end
  end

  context "extended model classes with a 'before' soft-delete hook" do
    let(:model_class) do
      mc = create_model(table_name) do
        primary_key :id
        timestamptz :deleted_at
      end
      mc.class_eval do
        attr_accessor :hook_body

        def before_soft_delete
          self.hook_body.call
        end
      end
      mc.plugin(:soft_deletes, column: :deleted_at)
      mc
    end

    it "has its hook called whenever an instance is soft-deleted" do
      instance = model_class.create

      called = false
      instance.hook_body = lambda do
        called = true
      end
      instance.soft_delete

      expect(instance).to be_is_soft_deleted
      expect(called).to eq(true)
    end

    it "is not soft-deleted if its hook returns false" do
      instance = model_class.create

      instance.hook_body = lambda do
        false
      end

      expect do
        instance.soft_delete
      end.to raise_error(Sequel::HookFailed, /before_soft_delete hook failed/i)

      expect(instance).not_to be_soft_deleted
    end
  end

  context "extended model classes with an 'after' soft-delete hook" do
    let(:model_class) do
      mc = create_model(table_name) do
        primary_key :id
        timestamptz :deleted_at
      end
      mc.class_eval do
        attr_accessor :hook_body

        def after_soft_delete
          self.hook_body.call
        end
      end
      mc.plugin(:soft_deletes, column: :deleted_at)
      mc
    end

    it "has its hook called whenever an instance is soft-deleted" do
      instance = model_class.create

      called = false
      instance.hook_body = lambda do
        called = true
      end
      instance.soft_delete

      expect(instance).to be_is_soft_deleted
      expect(called).to eq(true)
    end

    it "is still soft-deleted even if its hook returns false" do
      instance = model_class.create

      instance.hook_body = lambda do
        false
      end

      expect { instance.soft_delete }.not_to raise_error

      expect(instance).to be_is_soft_deleted
    end
  end

  context "extended model classes with an 'around' soft-delete hook" do
    let(:model_class) do
      mc = create_model(table_name) do
        primary_key :id
        timestamptz :deleted_at
      end
      mc.class_eval do
        attr_accessor :hook_body

        def around_soft_delete
          super if self.hook_body.call
        end
      end
      mc.plugin(:soft_deletes, column: :deleted_at)
      mc
    end

    it "has its hook called whenever an instance is soft-deleted" do
      instance = model_class.create

      called = false
      instance.hook_body = lambda do
        called = true
      end
      instance.soft_delete

      expect(instance).to be_is_soft_deleted
      expect(called).to eq(true)
    end

    it "is not soft-deleted if its hook doesn't super" do
      instance = model_class.create

      instance.hook_body = lambda do
        false
      end

      expect do
        instance.soft_delete
      end.to raise_error(Sequel::HookFailed, /around_soft_delete hook failed/i)

      expect(instance).not_to be_soft_deleted
    end
  end

  context "extended model classes with deletion blockers" do
    let(:model_class) do
      mc = create_model(table_name) do
        primary_key :id
        timestamptz :deleted_at
      end
      mc.class_eval do
        attr_reader :stub_soft_deletion_blockers

        def initialize(*)
          @stub_soft_deletion_blockers = []
          super
        end

        def soft_deletion_blockers
          return self.stub_soft_deletion_blockers
        end
      end
      mc.plugin(:soft_deletes, column: :deleted_at)
      mc
    end

    it "is not soft-deleted if it has deletion blockers" do
      instance = model_class.create

      instance.stub_soft_deletion_blockers << "A BLOCKER"

      expect do
        instance.soft_delete
      end.to raise_error(Sequel::HookFailed, /before_soft_delete hook failed/i)

      expect(instance).not_to be_soft_deleted
    end

    it "raises an error if remove_soft_deletion_blockers hasn't been implemented" do
      instance = model_class.create

      expect do
        instance.remove_soft_deletion_blockers
      end.to raise_error(NotImplementedError)
    end
  end
end
