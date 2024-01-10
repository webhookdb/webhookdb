# frozen_string_literal: true

require "webhookdb/async/autoscaler"

RSpec.describe Webhookdb::Async::Autoscaler do
  describe "configuration", reset_configuration: described_class do
    it "errors for an invalid provider" do
      described_class.provider = "x"
      expect do
        described_class.run_after_configured_hooks
      end.to raise_error(RuntimeError, /invalid AUTOSCALER_PROVIDER: 'x', one of: heroku, fake/)
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
      end.to raise_error(RuntimeError, /invalid AUTOSCALER_PROVIDER: '', one of: heroku, fake/)
    end
  end

  describe "build_implementation", reset_configuration: described_class do
    it "works for a heroku provider", reset_configuration: Webhookdb::Heroku do
      described_class.provider = "heroku"
      described_class.heroku_app_id_or_app_name = "fake-app"
      Webhookdb::Heroku.oauth_token = "x"
      expect(described_class.build_implementation).to have_attributes(
        heroku: Webhookdb::Heroku.client,
        active_event_initial_workers: nil,
        max_additional_workers: 2,
        app_id_or_app_name: "fake-app",
        formation_id_or_formation_type: "worker",
      )
    end

    it "works for a fake provider" do
      described_class.provider = "fake"
      impl = described_class.build_implementation
      impl.scale_up({}, depth: 1, x: 1)
      impl.scale_down(x: 1)
      expect(impl).to have_attributes(
        scale_ups: [[{}, {depth: 1, x: 1}]],
        scale_downs: [[{x: 1}]],
      )
    end
  end
end
