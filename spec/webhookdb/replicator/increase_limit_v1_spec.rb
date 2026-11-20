# frozen_string_literal: true

require_relative "increase_shared_examples"

RSpec.describe Webhookdb::Replicator::IncreaseLimitV1, :db do
  it_behaves_like "an Increase replicator dependent on events and increase_app_v1" do
    let(:list_path) { "/limits" }
    let(:denormalized_key) { :model_id }
    let(:created_at_column) { :row_created_at }
    let(:doc_resource_json) { <<~JSON }
      {
        "id": "limit_fku42k0qtc8ulsuas38q",
        "interval": "month",
        "metric": "volume",
        "model_id": "ach_route_yy0yirrxa4pblzl0k4op",
        "model_type": "ach_route",
        "status": "active",
        "type": "limit",
        "value": 0
      }
    JSON
  end
end
