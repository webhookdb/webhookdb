# frozen_string_literal: true

require "support/shared_examples_for_services"

RSpec.describe Webhookdb::Services::TheranestServiceTypeV1, :db do
  let(:org) { Webhookdb::Fixtures.organization.create }
  let(:fac) { Webhookdb::Fixtures.service_integration(organization: org) }
  let(:dependency) do
    fac.create(service_name: "theranest_auth_v1", api_url: "https://auth-api-url.com", backfill_key: "username",
               backfill_secret: "password",)
  end
  let(:dep_svc) { dependency.service_instance }
  let(:sint) { fac.depending_on(dependency).create(service_name: "theranest_service_type_v1").refresh }
  let(:svc) { sint.service_instance }

  def auth_stub_request
    return stub_request(:post, "https://fake-url.com/home/signin").to_return(
      status: 200,
      headers: {"Set-Cookie" => "new_cookie"},
    )
  end

  before(:each) do
    auth_stub_request
  end

  it_behaves_like "a service implementation", "theranest_service_type_v1" do
    let(:body) do
      JSON.parse(<<~J)
                  {
           "staffPositionIds":null,
           "isNonBillable":false,
           "isArchived":false,
           "key":"",
           "label":"*No Service Type*",
           "selected":true,
           "color":null,
           "textColor":null
        }
      J
    end
    let(:expected_data) { body }
    let(:supports_row_diff) { false }
  end

  it_behaves_like "a service implementation dependent on another", "theranest_service_type_v1", "theranest_auth_v1" do
    let(:no_dependencies_message) { "This integration requires Theranest Auth to sync" }
  end

  describe "backfill process" do
    let(:page1_response) do
      <<~R
                        {
           "ServiceTypes":[
              {
                 "staffPositionIds":null,
                 "isNonBillable":false,
                 "isArchived":false,
                 "key":"",
                 "label":"*No Service Type*",
                 "selected":true,
                 "color":null,
                 "textColor":null
              },
              {
                 "staffPositionIds":[
        #{'            '}
                 ],
                 "isNonBillable":false,
                 "isArchived":false,
                 "key":"abc123",
                 "label":"Behavioral health counseling and therapy, per 15 minutes",
                 "selected":true,
                 "color":"#333333",
                 "textColor":"#FFFFFF"
              },
              {
                 "staffPositionIds":[
        #{'            '}
                 ],
                 "isNonBillable":false,
                 "isArchived":false,
                 "key":"def456",
                 "label":"Case management, each 15 minutes",
                 "selected":true,
                 "color":"#333333",
                 "textColor":"#FFFFFF"
              }
           ],
           "Staff": [],
           "Locations": [],
           "Clients": []
        }
      R
    end

    before(:each) do
      org.prepare_database_connections
      svc.create_table
      dep_svc.create_table
      stub_auth_request
    end

    after(:each) do
      org.remove_related_database
    end

    def stub_auth_request
      return stub_request(:post, "https://auth-api-url.com/home/signin").
          to_return(status: 200, body: "", headers: {})
    end

    def stub_service_requests
      return [
        stub_request(:get, "https://auth-api-url.com/api/appointments/GetFilterValues").
            to_return(status: 200, body: page1_response, headers: {"Content-Type" => "application/json"}),
      ]
    end

    def stub_service_request_error
      return stub_request(:get, "https://auth-api-url.com/api/appointments/GetFilterValues").
          to_return(status: 503, body: "uhh")
    end

    it "inserts records for pages of results" do
      responses = stub_service_requests
      svc.backfill
      expect(responses).to all(have_been_made)
      rows = svc.readonly_dataset(&:all)
      expect(rows).to have_length(2)
      expect(rows).to contain_exactly(
        include(external_id: "abc123"),
        include(external_id: "def456"),
      )
    end

    it "retries the page fetch" do
      expect(Webhookdb::Backfiller).to receive(:do_retry_wait).twice # Mock out the sleep
      expect(svc).to receive(:_fetch_backfill_page).and_raise(RuntimeError)
      expect(svc).to receive(:_fetch_backfill_page).and_raise(RuntimeError)
      responses = stub_service_requests
      expect(svc).to receive(:_fetch_backfill_page).at_least(:once).and_call_original

      svc.backfill
      expect(responses).to all(have_been_made)
      svc.readonly_dataset { |ds| expect(ds.all).to have_length(2) }
    end

    it "errors if fetching page errors" do
      expect(Webhookdb::Backfiller).to receive(:do_retry_wait).twice # Mock out the sleep
      response = stub_service_request_error
      expect { svc.backfill }.to raise_error(Webhookdb::Http::Error)
      expect(response).to have_been_made.at_least_once
    end

    # TODO: add this once the integration has dependents
    # it "emits the backfill event for dependencies when cascade is true", :async, :do_not_defer_events do
    #   stub_service_requests
    #   case_sint =
    #     Webhookdb::Fixtures.service_integration.organization(sint.organization).
    #       depending_on(sint).create(service_name: "theranest_case_v1")
    #   expect do
    #     svc.backfill(cascade: true)
    #   end.to publish("webhookdb.serviceintegration.backfill").with_payload([case_sint.id, {"cascade" => true}])
    # end
  end

  describe "state machine calculation" do
    describe "calculate_create_state_machine" do
      it "prompts for dependencies" do
        sint.update(depends_on: nil)
        dependency.destroy
        sm = sint.calculate_create_state_machine
        expect(sm).to have_attributes(
          output: match("This integration requires Theranest Auth to sync"),
        )
      end

      it "succeeds and prints a success response if the dependency is set" do
        sint.webhook_secret = "whsec_abcasdf"
        sm = sint.calculate_create_state_machine
        expect(sm).to have_attributes(
          needs_input: false,
          complete: true,
          output: match("If you have fully set up"),
        )
      end
    end

    describe "calculate_backfill_state_machine" do
      it "returns org database info" do
        sm = sint.calculate_backfill_state_machine
        expect(sm).to have_attributes(
          needs_input: false,
          complete: true,
          output: match("start backfilling Theranest Service Type").and(match("you can query Theranest Service Types")),
        )
      end
    end
  end

  describe "mixin methods" do
    let(:org) { Webhookdb::Fixtures.organization.create }
    let(:fac) { Webhookdb::Fixtures.service_integration(organization: org) }
    let(:dependency) { fac.create(service_name: "theranest_auth_v1") }
    let(:sint) { fac.depending_on(dependency).create(service_name: "theranest_service_type_v1").refresh }

    it "can find parent auth integration" do
      auth_parent = sint.service_instance.find_auth_integration
      expect(auth_parent.id).to eq(dependency.id)
    end

    it "returns error if no auth parent present" do
      sint.depends_on = nil
      expect do
        sint.service_instance.find_auth_integration
      end.to raise_error(Webhookdb::InvalidPostcondition)
    end
  end
end
