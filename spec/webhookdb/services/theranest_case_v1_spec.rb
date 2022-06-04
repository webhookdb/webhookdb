# frozen_string_literal: true

require "support/shared_examples_for_services"

RSpec.describe Webhookdb::Services::TheranestCaseV1, :db do
  let(:auth) do
    fac.create(service_name: "theranest_auth_v1",
               backfill_key: "username",
               backfill_secret: "password",
               api_url: "https://fake-url.com",)
  end
  let(:client_id_one) { SecureRandom.hex(5) }
  let(:client_id_two) { SecureRandom.hex(5) }
  let(:auth_svc) { auth.service_instance }
  let(:org) { Webhookdb::Fixtures.organization.create }
  let(:client_sint) { fac.depending_on(auth).create(service_name: "theranest_client_v1") }
  let(:client_svc) { client_sint.service_instance }
  let(:sint) { fac.depending_on(client_sint).create(service_name: "theranest_case_v1").refresh }
  let(:svc) { sint.service_instance }
  let(:fac) { Webhookdb::Fixtures.service_integration(organization: org) }

  def auth_stub_request
    return stub_request(:post, "https://fake-url.com/home/signin").to_return(
      status: 200,
      headers: {"Set-Cookie" => "new_cookie"},
    )
  end

  def insert_client_rows
    client_svc.admin_dataset do |ds|
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

  describe "basic service integration functionality" do
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

  it_behaves_like "a service implementation dependent on another", "theranest_case_v1", "theranest_client_v1" do
    let(:no_dependencies_message) { "This integration requires Theranest Clients to sync" }
  end

  describe "backfill process" do
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

    before(:each) do
      org.prepare_database_connections
      auth_svc.create_table
      client_svc.create_table
      svc.create_table
      insert_client_rows
    end

    after(:each) do
      org.remove_related_database
    end

    def stub_service_requests
      return [
        stub_request(:get, "https://fake-url.com/api/cases/getClientCases?clientId=#{client_id_one}").
            to_return(status: 200, body: page1_response, headers: {"Content-Type" => "application/json"}),
        stub_request(:get, "https://fake-url.com/api/cases/getClientCases?clientId=#{client_id_two}").
            to_return(status: 200, body: page2_response, headers: {"Content-Type" => "application/json"}),
      ]
    end

    def stub_service_request_error
      return stub_request(:get, "https://fake-url.com/api/cases/getClientCases?clientId=#{client_id_one}").
          to_return(status: 503, body: "uhh")
    end

    it "inserts records for pages of results" do
      # this implicitly tests that the service integration can insert into its table
      responses = stub_service_requests
      svc.backfill
      expect(responses).to all(have_been_made)
      rows = svc.readonly_dataset(&:all)
      expect(rows).to have_length(5)
      expect(rows).to contain_exactly(
        include(external_id: "case123", state: "open"),
        include(external_id: "case456", state: "closed"),
        include(external_id: "case789", state: "deleted"),
        include(external_id: "caseABC", state: "open"),
        include(external_id: "caseDEF", state: "closed"),
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
      J
      Webhookdb::Fixtures.webhook_subscription(service_integration: sint).create
      expect(Webhookdb::Jobs::SendWebhook).to receive(:perform_async).
        with(include(
               "payload" => match_array([sint.id, hash_including("row", "external_id", "external_id_column")]),
             ))
      # this integration has no exact equivalent for `upsert_webhook`. `handle_item` mimics its functionality.
      backfiller = Webhookdb::Services::TheranestCaseV1::CaseBackfiller.new(
        case_svc: svc,
        theranest_client_id: client_id_one,
      )
      backfiller.handle_item(body)
    end

    it "emits the backfill event for dependencies when cascade is true", :async, :do_not_defer_events do
      stub_service_requests
      note_sint = fac.depending_on(sint).create(service_name: "theranest_progress_note_v1")
      expect do
        svc.backfill(cascade: true)
      end.to publish("webhookdb.serviceintegration.backfill").with_payload([note_sint.id, {"cascade" => true}])
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
