# frozen_string_literal: true

require "webhookdb/oauth"

RSpec.describe Webhookdb::Oauth, :db do
  describe Webhookdb::Oauth::Session do
    it "knows about usable sessions" do
      Timecop.freeze(31.minutes.ago) do
        old = Webhookdb::Fixtures.oauth_session.create
      end
      used = Webhookdb::Fixtures.oauth_session.create(used_at: Time.now)
      usable = Webhookdb::Fixtures.oauth_session.create
      expect(described_class.usable.all).to contain_exactly(be === usable)
    end
  end

  describe "Provider" do
    describe "#find_or_create_customer" do
      it "errors if provider requires auth" do
        cls = Class.new(described_class::Provider) do
          def requires_webhookdb_auth? = true
        end
        expect do
          cls.new.find_or_create_customer(tokens: nil, scope: nil)
        end.to raise_error(RuntimeError, /not be called/)
      end

      it "raises NIE if provider does not require auth" do
        cls = Class.new(described_class::Provider) do
          def requires_webhookdb_auth? = false
        end
        expect do
          cls.new.find_or_create_customer(tokens: nil, scope: nil)
        end.to raise_error(NotImplementedError)
      end
    end
  end
end
