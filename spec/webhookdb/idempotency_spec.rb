# frozen_string_literal: true

RSpec.describe "Webhookdb::Idempotency", db: :no_transaction do
  let(:described_class) { Webhookdb::Idempotency }

  describe "::every" do
    it "invokes the callback again only after a certain time has elapsed" do
      count = 0
      start = Time.now
      expect do
        Timecop.freeze(start) do
          3.times do
            described_class.every(12.hours).under_key("some-key") { count += 1 }
            Timecop.travel(1.hours)
            described_class.every(12.hours).under_key("some-key") { count += 1 }
            Timecop.travel(13.hours)
          end
        end
      end.to change { count }.by(3)
    end
  end

  describe "::once_ever" do
    it "only invokes the callback the first time" do
      count = 0
      expect do
        3.times do
          described_class.once_ever.under_key("some-key") { count += 1 }
        end
      end.to change { count }.by(1)
    end
  end

  describe "every and once_ever" do
    it "returns the block result if the callback executes, NOOP if not" do
      expect(described_class.once_ever.under_key("some-key") { 5 }).to eq(5)
      expect(described_class.once_ever.under_key("some-key") { 5 }).to eq(described_class::NOOP)
    end

    it "raises if inside of a transaction" do
      described_class.db.transaction do
        expect do
          described_class.once_ever.under_key("some-key") { 5 }
        end.to raise_error(Webhookdb::Postgres::InTransaction)
      end
    end

    it "can mark transactions ok" do
      described_class.db.transaction do
        expect(described_class.once_ever.transaction_ok.under_key("some-key") { 5 }).to eq(5)
      end
    end
  end

  describe "stored" do
    it "restores the block result if set" do
      expect(described_class.once_ever.under_key("unstored") { 5 }).to eq(5)
      expect(described_class.once_ever.under_key("unstored") { 5 }).to eq(described_class::NOOP)
      # return nil instead of noop if stored was asked for
      expect(described_class.once_ever.stored.under_key("unstored") { 5 }).to be_nil

      expect(described_class.once_ever.stored.under_key("stored-int") { 5 }).to eq(5)
      expect(described_class.once_ever.stored.under_key("stored-int") { raise RuntimeError }).to eq(5)

      expect(described_class.once_ever.stored.under_key("stored-hash") { {x: 1} }).to eq({"x" => 1})
      expect(described_class.once_ever.stored.under_key("stored-hash") { raise RuntimeError }).to eq({"x" => 1})
    end
  end

  describe "using_seperate_connection" do
    it "runs the idempotency on a separate database connection so it can be executed inside a transaction" do
      described_class.dataset.truncate
      described_class.db.transaction do
        expect(described_class.once_ever.using_seperate_connection.under_key("x") { 5 }).to eq(5)
        expect(described_class.once_ever.using_seperate_connection.under_key("x") { 5 }).to eq(described_class::NOOP)
      end
    end
  end

  describe "in_memory" do
    it "runs the idempotency in memory" do
      count = 0
      start = Time.now
      expect do
        Timecop.freeze(start) do
          3.times do
            described_class.every(12.hours).in_memory.under_key("some-key") { count += 1 }
            Timecop.travel(1.hours)
            described_class.every(12.hours).in_memory.under_key("some-key") { count += 1 }
            Timecop.travel(13.hours)
          end
        end
      end.to change { count }.by(3)
      expect(described_class.all).to be_empty
    end

    it "can use storage" do
      expect(described_class.once_ever.in_memory.under_key("unstored") { 5 }).to eq(5)
      expect(described_class.once_ever.in_memory.under_key("unstored") { 5 }).to eq(described_class::NOOP)
      # return nil instead of noop if stored was asked for
      expect(described_class.once_ever.in_memory.stored.under_key("unstored") { 5 }).to be_nil

      expect(described_class.once_ever.in_memory.stored.under_key("stored-int") { 5 }).to eq(5)
      expect(described_class.once_ever.in_memory.stored.under_key("stored-int") { raise "not hit" }).to eq(5)

      expect(described_class.once_ever.in_memory.stored.under_key("stored-hash") { {x: 1} }).to eq({"x" => 1})
      expect(described_class.once_ever.in_memory.stored.under_key("stored-hash") { raise "not hit" }).to eq({"x" => 1})
    end
  end
end
