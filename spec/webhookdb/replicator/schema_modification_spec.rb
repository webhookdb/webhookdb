# frozen_string_literal: true

RSpec.describe Webhookdb::Replicator::SchemaModification do
  fake_db = Class.new do
    attr_reader :calls

    def <<(stmt)
      @calls ||= []
      @calls << stmt
    end
  end

  describe "execute" do
    it "runs transactional statements at once, then each non-transactional, and then each application statement" do
      sh = described_class.new
      sh.transaction_statements << "t1"
      sh.transaction_statements << "t2"
      sh.nontransaction_statements << "n1"
      sh.application_database_statements << "a1"
      sh.application_database_statements << "a2"

      org_db = fake_db.new
      app_db = fake_db.new
      expect(Webhookdb::Postgres::Model).to receive(:db).and_return(app_db)
      sh.execute(org_db)
      expect(org_db.calls).to eq(["t1;\nt2;", "n1"])
      expect(app_db.calls).to eq(["a1;\na2;"])
    end
  end
end
