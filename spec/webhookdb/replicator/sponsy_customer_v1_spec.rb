# frozen_string_literal: true

require "support/shared_examples_for_replicators"

RSpec.describe Webhookdb::Replicator::SponsyCustomerV1, :db do
  let(:org) { Webhookdb::Fixtures.organization.create }
  let(:fac) { Webhookdb::Fixtures.service_integration(organization: org) }
  let(:slot_sint) { fac.create(service_name: "sponsy_slot_v1") }
  let(:sint) { fac.depending_on(slot_sint).create(service_name: "sponsy_customer_v1").refresh }
  let(:svc) { sint.replicator }

  it_behaves_like "a replicator" do
    let(:body) do
      JSON.parse(<<~J)
        {
          "id": "5ae523c0-56a9-408f-9e51-94f09cf29ca4",
          "createdAt": "2022-03-08T22:28:35.236Z",
          "updatedAt": "2022-03-08T22:28:35.236Z",
          "name": "Honeycomb.io",
          "logo": "http://res.cloudinary.com/djsp41f7o/image/upload/v1646778514/gneszzj5en0lgqwgebgx.jpg",
          "notes": null,
          "portalText": null,
          "portalId": "c5601d44-c759-48ae-8d0e-50495e004444"
        }
      J
    end
  end

  it_behaves_like "a replicator that may have a minimal body" do
    let(:body) do
      JSON.parse(<<~J)
        {
          "id": "5ae523c0-56a9-408f-9e51-94f09cf29ca4",
          "createdAt": "2022-03-08T22:28:35.236Z",
          "updatedAt": "2022-03-08T22:28:35.236Z",
          "name": "Honeycomb.io"
        }
      J
    end
  end

  it_behaves_like "a replicator that prevents overwriting new data with old" do
    let(:old_body) do
      JSON.parse(<<~J)
        {
          "id": "5ae523c0-56a9-408f-9e51-94f09cf29ca4",
          "createdAt": "2022-03-08T22:28:35.236Z",
          "updatedAt": "2022-03-08T22:28:35.236Z",
          "name": "Honeycomb.io",
          "logo": "http://res.cloudinary.com/djsp41f7o/image/upload/v1646778514/gneszzj5en0lgqwgebgx.jpg",
          "notes": null,
          "portalText": null,
          "portalId": "c5601d44-c759-48ae-8d0e-50495e004444"
        }
      J
    end
    let(:new_body) do
      JSON.parse(<<~J)
        {
          "id": "5ae523c0-56a9-408f-9e51-94f09cf29ca4",
          "createdAt": "2022-03-08T22:28:35.236Z",
          "updatedAt": "2022-03-18T22:28:35.236Z",
          "name": "Honeycomb.io",
          "logo": "http://res.cloudinary.com/djsp41f7o/image/upload/v1646778514/gneszzj5en0lgqwgebgx.jpg",
          "notes": null,
          "portalText": null,
          "portalId": "c5601d44-c759-48ae-8d0e-50495e004444"
        }
      J
    end
  end

  it_behaves_like "a replicator dependent on another", "sponsy_slot_v1" do
    let(:no_dependencies_message) { "This integration requires Sponsy Slots to sync" }
  end

  it_behaves_like "a replicator backfilling against the table of its dependency" do
    let(:external_id_col) { :sponsy_id }
    def create_dependency_row(external_id, ts)
      return {
        sponsy_id: "slot-#{external_id}",
        created_at: ts,
        updated_at: ts,
        data: {
          customer: {
            id: external_id,
            createdAt: "2022-03-08T22:28:35.236Z",
            updatedAt: "2022-03-08T22:28:35.236Z",
            name: "Some Customer",
            logo: "",
            notes: nil,
            portalText: nil,
            portalId: "c5601d44-c759-48ae-8d0e-50495e004444",
          },
        }.to_json,
      }
    end
  end

  describe "state machine calculation" do
    describe "calculate_backfill_state_machine" do
      it "prompts for dependencies" do
        sint.update(depends_on: nil)
        slot_sint.destroy
        sm = sint.replicator.calculate_backfill_state_machine
        expect(sm).to have_attributes(output: /You don't have any Sponsy Slot integrations yet/)
      end

      it "succeeds and prints a success response if the dependency is set" do
        sm = sint.replicator.calculate_backfill_state_machine
        expect(sm).to have_attributes(
          needs_input: false,
          complete: true,
          output: /We will start replicating Sponsy Customers into your WebhookDB database/,
        )
      end
    end
  end
end
