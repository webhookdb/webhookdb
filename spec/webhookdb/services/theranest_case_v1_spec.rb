# frozen_string_literal: true

require "support/shared_examples_for_services"

RSpec.describe Webhookdb::Services::TheranestCaseV1, :db do
  let(:auth) do
    fac.create(service_name: "theranest_auth_v1",
               backfill_key: "username",
               backfill_secret: "password",
               api_url: "https://auth-api-url.com",)
  end
  let(:client_id_one) { SecureRandom.hex(5) }
  let(:client_id_two) { SecureRandom.hex(5) }
  let(:org) { Webhookdb::Fixtures.organization.create }
  let(:client_sint) { fac.depending_on(auth).create(service_name: "theranest_client_v1") }
  let(:client_svc) { client_sint.service_instance }
  let(:sint) { fac.depending_on(client_sint).create(service_name: "theranest_case_v1").refresh }
  let(:svc) { sint.service_instance }
  let(:fac) { Webhookdb::Fixtures.service_integration(organization: org) }

  def auth_stub_request
    return stub_request(:post, "https://auth-api-url.com/home/signin").to_return(
      status: 200,
      headers: {"Set-Cookie" => "new_cookie"},
    )
  end

  def insert_client_rows(dep_svc)
    dep_svc.admin_dataset do |ds|
      ds.multi_insert([
                        {
                          data: "{}",
                          theranest_id: client_id_one,
                        },
                        {
                          data: "{}",
                          theranest_id: client_id_two,
                        },
                      ])
      return ds.order(:pk).last
    end
  end

  before(:each) { auth_stub_request }

  it_behaves_like "a service implementation", "theranest_case_v1" do
    let(:body) do
      # this is an enhanced json body, which mimics the preparation done in `handle_item`,
      # NOT the response we get from the API
      JSON.parse(<<~J)
        {
                    "CaseId": "case456",
                    "Date": "05/04/2022",
                    "CaseName": "Betty White (closed)",
                    "ServiceType": "90834: Psychotherapy, 45 minutes with patient and/or family member",
                    "IsGroupCase": false,
                    "NoteDetails": [],
                    "Status": "Closed",
                    "DeletedByName": null,
                    "DeletedDate": null,
                    "IsAba": false,
                    "IsPqrsEnabled": false,
                    "external_client_id": "#{client_id_one}",#{' '}
                    "state": "closed"
                }
      J
    end
  end

  it_behaves_like "a service implementation dependent on another", "theranest_case_v1", "theranest_client_v1" do
    let(:no_dependencies_message) { "This integration requires Theranest Clients to sync" }
  end

  it_behaves_like "a service implementation that can backfill", "theranest_case_v1" do
    let(:page1_response) do
      <<~R
                {
            "ClientInfo": {
                "ClientId": "#{client_id_one}",
                "ClientFullName": "Betty White"
            },
            "ClientGroupInfo": null,
            "OpenCases": [
                {
                    "CaseId": "case123",
                    "Date": "05/04/2022",
                    "CaseName": "Betty White",
                    "ServiceType": null,
                    "IsGroupCase": false,
                    "NoteDetails": [],
                    "Status": "Open",
                    "DeletedByName": null,
                    "DeletedDate": null,
                    "IsAba": false,
                    "IsPqrsEnabled": false
                }
            ],
            "ClosedCases": [
                {
                    "CaseId": "case456",
                    "Date": "05/04/2022",
                    "CaseName": "Betty White (closed)",
                    "ServiceType": "90834: Psychotherapy, 45 minutes with patient and/or family member",
                    "IsGroupCase": false,
                    "NoteDetails": [],
                    "Status": "Closed",
                    "DeletedByName": null,
                    "DeletedDate": null,
                    "IsAba": false,
                    "IsPqrsEnabled": false
                }
            ],
            "DeletedCases": [
                {
                    "CaseId": "case789",
                    "Date": "05/04/2022",
                    "CaseName": "Betty White (deleted) ",
                    "ServiceType": "Q3014: Telehealth originating site facility fee",
                    "IsGroupCase": false,
                    "NoteDetails": [],
                    "Status": "Open",
                    "DeletedByName": "Rob Galanakis",
                    "DeletedDate": "05/04/2022",
                    "IsAba": false,
                    "IsPqrsEnabled": false
                }
            ],
            "CanReOpenCases": false,
            "OpenCasesExistButUserCanNotSeeAnyOfThem": false,
            "IsVerboseCaseNotificationDismissed": false
        }

      R
    end
    let(:page2_response) do
      <<~R
                {
            "ClientInfo": {
                "ClientId": "#{client_id_two}",
                "ClientFullName": "Betty White"
            },
            "ClientGroupInfo": null,
            "OpenCases": [
                {
                    "CaseId": "caseABC",
                    "Date": "05/01/2022",
                    "CaseName": "Bea Arthur",
                    "ServiceType": null,
                    "IsGroupCase": false,
                    "NoteDetails": [],
                    "Status": "Open",
                    "DeletedByName": null,
                    "DeletedDate": null,
                    "IsAba": false,
                    "IsPqrsEnabled": false
                }
            ],
            "ClosedCases": [
                {
                    "CaseId": "caseDEF",
                    "Date": "05/01/2022",
                    "CaseName": "Bea Arthur (closed)",
                    "ServiceType": "90834: Psychotherapy, 45 minutes with patient and/or family member",
                    "IsGroupCase": false,
                    "NoteDetails": [],
                    "Status": "Closed",
                    "DeletedByName": null,
                    "DeletedDate": null,
                    "IsAba": false,
                    "IsPqrsEnabled": false
                }
            ],
            "DeletedCases": [
            ],
            "CanReOpenCases": false,
            "OpenCasesExistButUserCanNotSeeAnyOfThem": false,
            "IsVerboseCaseNotificationDismissed": false
        }

      R
    end
    let(:expected_items_count) { 5 }

    def insert_required_data_callback
      return ->(dep_svc) { insert_client_rows(dep_svc) }
    end

    def stub_service_requests
      return [
        stub_request(:get, "https://auth-api-url.com/api/cases/getClientCases?clientId=#{client_id_one}").
            to_return(status: 200, body: page1_response, headers: {"Content-Type" => "application/json"}),
        stub_request(:get, "https://auth-api-url.com/api/cases/getClientCases?clientId=#{client_id_two}").
            to_return(status: 200, body: page2_response, headers: {"Content-Type" => "application/json"}),
      ]
    end

    def stub_service_request_error
      return stub_request(:get, "https://auth-api-url.com/api/cases/getClientCases?clientId=#{client_id_one}").
          to_return(status: 503, body: "uhh")
    end
  end

  describe "specialized backfill behavior" do
    it "returns credentials missing error if creds are missing from corresponding auth integration" do
      auth.update(backfill_key: "", backfill_secret: "")
      expect do
        svc.backfill
      end.to raise_error(Webhookdb::Services::CredentialsMissing).with_message(/requires Theranest Username/)
    end
  end

  describe "state machine calculation" do
    describe "calculate_create_state_machine" do
      it "prompts for dependencies" do
        sint.update(depends_on: nil)
        client_sint.destroy
        sm = sint.calculate_create_state_machine
        expect(sm).to have_attributes(
          output: match("This integration requires Theranest Clients to sync"),
        )
      end

      it "succeeds and prints a success response if the dependency is set" do
        sint.webhook_secret = "whsec_abcasdf"
        sm = sint.calculate_create_state_machine
        expect(sm).to have_attributes(
          needs_input: false,
          complete: true,
          output: /You are all set/,
        )
      end
    end

    describe "calculate_backfill_state_machine" do
      it "returns org database info" do
        sm = sint.calculate_backfill_state_machine
        expect(sm).to have_attributes(
          needs_input: false,
          complete: true,
          output: match("We will start backfilling Theranest Case").and(match("you can query Theranest Cases")),
        )
      end
    end
  end

  describe "mixin methods" do
    it "can find parent auth integration" do
      auth_parent = sint.service_instance.find_auth_integration
      expect(auth_parent.id).to eq(auth.id)
    end

    it "returns error if no auth parent present" do
      sint.depends_on = nil
      expect do
        sint.service_instance.find_auth_integration
      end.to raise_error(Webhookdb::InvalidPostcondition)
    end
  end
end
