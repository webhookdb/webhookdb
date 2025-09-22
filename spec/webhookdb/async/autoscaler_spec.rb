# frozen_string_literal: true

require "webhookdb/async/autoscaler"

RSpec.describe Webhookdb::Async::Autoscaler do
  describe "build_implementation", reset_configuration: described_class do
    it "conditionally adds handlers", reset_configuration: Webhookdb::Heroku do
      Webhookdb::Heroku.oauth_token = "x"
      described_class.handlers = "heroku+sentry"
      as = described_class.build
      expect(as.handler.chain).to contain_exactly(
        be_a(Amigo::Autoscaler::Handlers::Log),
        be_a(Amigo::Autoscaler::Handlers::Heroku),
        be_a(Amigo::Autoscaler::Handlers::Sentry),
      )

      described_class.handlers = "heroku"
      as = described_class.build
      expect(as.handler.chain).to contain_exactly(
        be_a(Amigo::Autoscaler::Handlers::Log),
        be_a(Amigo::Autoscaler::Handlers::Heroku),
      )

      described_class.handlers = "sentry"
      as = described_class.build
      expect(as.handler.chain).to contain_exactly(
        be_a(Amigo::Autoscaler::Handlers::Log),
        be_a(Amigo::Autoscaler::Handlers::Sentry),
      )

      described_class.handlers = ""
      as = described_class.build
      expect(as.handler.chain).to contain_exactly(
        be_a(Amigo::Autoscaler::Handlers::Log),
      )
    end
  end
end
