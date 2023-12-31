# frozen_string_literal: true

require "webhookdb/async/autoscaler"

RSpec.describe Webhookdb::Async::Autoscaler do
  describe "configuration", reset_configuration: described_class do
    it "errors for an invalid provider" do
      described_class.provider = "x"
      expect do
        described_class.run_after_configured_hooks
      end.to raise_error(RuntimeError, /invalid AUTOSCALER_PROVIDER: 'x', one of: heroku/)
    end

    it "allows a valid provider" do
      described_class.provider = "heroku"
      expect { described_class.run_after_configured_hooks }.to_not raise_error
    end

    it "allows an empty provider if enabled is false" do
      described_class.provider = ""
      described_class.enabled = false
      expect { described_class.run_after_configured_hooks }.to_not raise_error
    end

    it "errors for an empty provider if enabled is true" do
      described_class.provider = ""
      described_class.enabled = true
      expect do
        described_class.run_after_configured_hooks
      end.to raise_error(RuntimeError, /invalid AUTOSCALER_PROVIDER: '', one of: heroku/)
    end
  end
end
