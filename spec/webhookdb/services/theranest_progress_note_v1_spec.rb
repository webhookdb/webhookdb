# frozen_string_literal: true

require "support/shared_examples_for_services"

RSpec.describe Webhookdb::Services::TheranestProgressNoteV1, :db do
  let(:auth) do
    fac.create(service_name: "theranest_auth_v1",
               backfill_key: "username",
               backfill_secret: "password",
               api_url: "https://auth-api-url.com",)
  end
  let(:case_id_one) { SecureRandom.hex(5) }
  let(:case_id_two) { SecureRandom.hex(5) }
  let(:auth_svc) { auth.service_instance }
  let(:org) { Webhookdb::Fixtures.organization.create }
  let(:client_sint) { fac.depending_on(auth).create(service_name: "theranest_client_v1") }
  let(:client_svc) { client_sint.service_instance }
  let(:case_sint) { fac.depending_on(client_sint).create(service_name: "theranest_case_v1").refresh }
  let(:case_svc) { case_sint.service_instance }
  let(:sint) { fac.depending_on(case_sint).create(service_name: "theranest_progress_note_v1").refresh }
  let(:svc) { sint.service_instance }
  let(:fac) { Webhookdb::Fixtures.service_integration(organization: org) }

  def auth_stub_request
    return stub_request(:post, "https://auth-api-url.com/home/signin").to_return(
      status: 200,
      headers: {"Set-Cookie" => "new_cookie"},
    )
  end

  def insert_case_rows(dep_svc)
    dep_svc.admin_dataset do |ds|
      ds.multi_insert([
                        {
                          data: "{}",
                          external_id: case_id_one,
                          external_client_id: "client_id",
                          state: "open",
                        },
                        {
                          data: "{}",
                          external_id: case_id_two,
                          external_client_id: "client_id",
                          state: "closed",
                        },
                      ])
      return ds.order(:pk).last
    end
  end

  before(:each) { auth_stub_request }

  it_behaves_like "a service implementation", "theranest_progress_note_v1" do
    let(:body) do
      # this is an enhanced json body, which mimics the preparation done in `handle_item`,
      # NOT the response we get from the API
      JSON.parse(<<~J)
        {
          "Date": "05/06/2022 10:48 AM",
          "NoteId": "progressNoteABC",
          "CaseId": "#{case_id_two}",
          "Duration": 60,
          "Details": "",
          "IsSigned": true,
          "IsApproved": false,
          "IsCreatedUsingWiley": false,
          "IsSignedByStaff": true,
          "AwaitingReview": false,
          "DetailsHeader": "Session Focus",
          "external_case_id": "#{case_id_two}",#{' '}
          "external_client_id": "client ID"
        }
      J
    end
  end

  it_behaves_like "a service implementation dependent on another", "theranest_progress_note_v1", "theranest_case_v1" do
    let(:no_dependencies_message) { "This integration requires Theranest Cases to sync" }
  end

  it_behaves_like "a service implementation that can backfill", "theranest_progress_note_v1" do
    let(:page1_response) do
      <<~R
        {
            "ClientId": "client_id",
            "ClientGroupId": null,
            "ClientGroupName": null,
            "CaseMembersSelectList": [
                {
                    "Value": "60341d7b41ec8113b47e8193",
                    "Text": "Sid Cidambi",
                    "IsSelected": true
                }
            ],
            "Notes": [
                {
                    "Date": "05/09/2022 09:45 AM",
                    "NoteId": "progressNote123",
                    "CaseId": "#{case_id_one}",
                    "Duration": 60,
                    "Details": "",
                    "IsSigned": false,
                    "IsApproved": false,
                    "IsCreatedUsingWiley": false,
                    "IsSignedByStaff": false,
                    "AwaitingReview": false,
                    "DetailsHeader": "Session Focus"
                }
            ],
            "IsSubscribedToWiley": false,
            "IsNonDefaultProgressNoteTemplatesEnabled": true,
            "HasOneOrMoreNotes": true,
            "CaseId": "#{case_id_one}",
            "CaseName": null,
            "IsClosed": false,
            "IsGroupCase": false,
            "IsAba": false
        }
      R
    end
    let(:page2_response) do
      <<~R
                        {
            "ClientId": "client_id",
            "ClientGroupId": null,
            "ClientGroupName": null,
            "CaseMembersSelectList": [
                {
                    "Value": "60341d7b41ec8113b47e8193",
                    "Text": "Sid Cidambi",
                    "IsSelected": true
                }
            ],
            "Notes": [
                {
                    "Date": "05/06/2022 10:48 AM",
                    "NoteId": "progressNoteABC",
                    "CaseId": "#{case_id_two}",
                    "Duration": 60,
                    "Details": "",
                    "IsSigned": true,
                    "IsApproved": false,
                    "IsCreatedUsingWiley": false,
                    "IsSignedByStaff": true,
                    "AwaitingReview": false,
                    "DetailsHeader": "Session Focus"
                }
            ],
            "IsSubscribedToWiley": false,
            "IsNonDefaultProgressNoteTemplatesEnabled": true,
            "HasOneOrMoreNotes": true,
            "CaseId": "#{case_id_two}",
            "CaseName": null,
            "IsClosed": false,
            "IsGroupCase": false,
            "IsAba": false
        }
      R
    end
    let(:expected_items_count) { 2 }

    def insert_required_data_callback
      return ->(dep_svc) { insert_case_rows(dep_svc) }
    end

    def stub_service_requests
      return [
        stub_request(:get, "https://auth-api-url.com/api/cases/get-progress-notes-list?caseId=#{case_id_one}").
            to_return(status: 200, body: page1_response, headers: {"Content-Type" => "application/json"}),
        stub_request(:get, "https://auth-api-url.com/api/cases/get-progress-notes-list?caseId=#{case_id_two}").
            to_return(status: 200, body: page2_response, headers: {"Content-Type" => "application/json"}),
      ]
    end

    def stub_service_request_error
      return stub_request(:get, "https://auth-api-url.com/api/cases/get-progress-notes-list?caseId=#{case_id_one}").
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
        case_sint.destroy
        sm = sint.calculate_create_state_machine
        expect(sm).to have_attributes(
          output: match("This integration requires Theranest Cases to sync"),
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
          output: match("We will start backfilling Theranest Progress Note").
                    and(match("you can query Theranest Progress Notes")),
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
