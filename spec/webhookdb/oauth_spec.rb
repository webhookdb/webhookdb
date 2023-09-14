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
end
