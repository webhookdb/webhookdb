# frozen_string_literal: true

require "support/shared_examples_for_services"

RSpec.describe Webhookdb::Services::TheranestProgressNoteV1, :db do
  let(:auth) do
    fac.create(service_name: "theranest_auth_v1",
               backfill_key: "username",
               backfill_secret: "password",
               api_url: "https://fake-url.com",)
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
    return stub_request(:post, "https://fake-url.com/home/signin").to_return(
      status: 200,
      headers: {"Set-Cookie" => "new_cookie"},
    )
  end

  def insert_case_rows
    case_svc.admin_dataset do |ds|
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

  describe "basic service integration functionality" do
    let(:body) do
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
          "DetailsHeader": "Session Focus"
        }
      J
    end

    before(:each) do
      org.prepare_database_connections
    end

    after(:each) do
      org.remove_related_database
    end

    it "can create its table in its org db" do
      svc.create_table
      svc.readonly_dataset do |ds|
        expect(ds.db).to be_table_exists(svc.table_sym)
      end
      expect(sint.db).to_not be_table_exists(svc.table_sym)
    end

    it "clears setup information" do
      sint.update(webhook_secret: "wh_sek")
      svc.clear_create_information
      expect(sint).to have_attributes(webhook_secret: "")
    end

    it "clears backfill information" do
      sint.update(api_url: "example.api.com", backfill_key: "bf_key", backfill_secret: "bf_sek")
      svc.clear_backfill_information
      expect(sint).to have_attributes(api_url: "")
      expect(sint).to have_attributes(backfill_key: "")
      expect(sint).to have_attributes(backfill_secret: "")
    end
  end

  it_behaves_like "a service implementation dependent on another", "theranest_progress_note_v1", "theranest_case_v1" do
    let(:no_dependencies_message) { "This integration requires Theranest Cases to sync" }
  end

  describe "backfill process" do
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

    before(:each) do
      org.prepare_database_connections
      auth_svc.create_table
      client_svc.create_table
      case_svc.create_table
      svc.create_table
      insert_case_rows
    end

    after(:each) do
      org.remove_related_database
    end

    def stub_service_requests
      return [
        stub_request(:get, "https://fake-url.com/api/cases/get-progress-notes-list?caseId=#{case_id_one}").
            to_return(status: 200, body: page1_response, headers: {"Content-Type" => "application/json"}),
        stub_request(:get, "https://fake-url.com/api/cases/get-progress-notes-list?caseId=#{case_id_two}").
            to_return(status: 200, body: page2_response, headers: {"Content-Type" => "application/json"}),
      ]
    end

    def stub_service_request_error
      return stub_request(:get, "https://fake-url.com/api/cases/get-progress-notes-list?caseId=#{case_id_one}").
          to_return(status: 503, body: "uhh")
    end

    it "inserts records for pages of results" do
      # this implicitly tests that the service integration can insert into its table
      responses = stub_service_requests
      svc.backfill
      expect(responses).to all(have_been_made)
      rows = svc.readonly_dataset(&:all)
      expect(rows).to have_length(2)
      expect(rows).to contain_exactly(
        include(external_id: "progressNote123"),
        include(external_id: "progressNoteABC"),
      )
    end

    it "errors if fetching page errors" do
      expect(Webhookdb::Backfiller).to receive(:do_retry_wait).twice # Mock out the sleep
      response = stub_service_request_error
      expect { svc.backfill }.to raise_error(Webhookdb::Http::Error)
      expect(response).to have_been_made.at_least_once
    end

    it "emits the rowupsert event", :async, :do_not_defer_events do
      body = JSON.parse(<<~J)
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
      J
      Webhookdb::Fixtures.webhook_subscription(service_integration: sint).create
      expect(Webhookdb::Jobs::SendWebhook).to receive(:perform_async).
        with(include(
               "payload" => match_array([sint.id, hash_including("row", "external_id", "external_id_column")]),
             ))
      # this integration has no exact equivalent for `upsert_webhook`. `handle_item` mimics its functionality.
      backfiller = Webhookdb::Services::TheranestProgressNoteV1::ProgressNoteBackfiller.new(
        progress_note_svc: svc,
        theranest_case_id: case_id_one,
        theranest_client_id: "client_id",
      )
      backfiller.handle_item(body)
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
