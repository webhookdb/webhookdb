# frozen_string_literal: true

require "webhookdb/async/web_autoscaler"

RSpec.describe Webhookdb::Async::WebAutoscaler do
  describe "build_implementation", reset_configuration: described_class do
    it "runs" do
      described_class.handlers = "sentry"
      as = described_class.build
      expect(as.handler.chain).to contain_exactly(
        be_a(Amigo::Autoscaler::Handlers::Log),
        be_a(Amigo::Autoscaler::Handlers::Sentry),
      )
    end
  end
end
