# frozen_string_literal: true

require "support/shared_examples_for_services"

RSpec.describe Webhookdb::Services::TheranestProgressNoteDocumentV1, :db do
  let(:auth) do
    fac.create(service_name: "theranest_auth_v1",
               backfill_key: "username",
               backfill_secret: "password",
               api_url: "https://fake-url.com",)
  end
  let(:auth_svc) { auth.service_instance }
  let(:org) { Webhookdb::Fixtures.organization.create }
  let(:client_sint) { fac.depending_on(auth).create(service_name: "theranest_client_v1") }
  let(:client_svc) { client_sint.service_instance }
  let(:case_sint) { fac.depending_on(client_sint).create(service_name: "theranest_case_v1").refresh }
  let(:case_svc) { case_sint.service_instance }
  let(:pnote_sint) { fac.depending_on(case_sint).create(service_name: "theranest_progress_note_v1").refresh }
  let(:pnote_svc) { pnote_sint.service_instance }
  let(:sint) { fac.depending_on(pnote_sint).create(service_name: "theranest_progress_note_document_v1").refresh }
  let(:svc) { sint.service_instance }
  let(:fac) { Webhookdb::Fixtures.service_integration(organization: org) }
  let(:pnote_id_one) { SecureRandom.hex(5) }
  let(:pnote_id_two) { SecureRandom.hex(5) }

  def auth_stub_request
    return stub_request(:post, "https://fake-url.com/home/signin").to_return(
      status: 200,
      headers: {"Set-Cookie" => "new_cookie"},
    )
  end

  def insert_progress_note_rows
    pnote_svc.admin_dataset do |ds|
      ds.multi_insert([
                        {
                          data: "{}",
                          external_id: pnote_id_one,
                          external_case_id: "case_id",
                        },
                        {
                          data: "{}",
                          external_id: pnote_id_two,
                          external_case_id: "case_id",
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
          "Checksum": "md5a9b47a8d00186143f4f687060b6c346e",
          "DocumentId": "62aa0bf757098cf2abcb86aa",
          "AppointmentId": null,
          "HasLinkedAppointment": false,
          "ClientId": "5f5d238c2ea814103c659682",
          "IsNoteSigned": true,
          "PdfUrl": "https://theraneststaging.theranest.com/api/signature/getSignedDocument/62aa0bf757098cf2abcb86aa",
          "DownloadUrl": "/api/signature/downloadSignedDocument/62aa0bf757098cf2abcb86aa",
          "IsCaseForm": false,
          "IsClientForm": false,
          "StaffSignerId": "623bb09367189f5667b325aa",
          "StaffSignatureUrl": "/api/signature/getSignatureImage/6275603b0141280c039ecbb6",
          "StaffSignerFullName": "Rob Galanakis",
          "StaffSignatureTransactionId": "3",
          "StaffSignedOn": "06/15/2022 09:42 AM",
          "IsStaffSigned": true,
          "ClientSignerId": "5f5d238c2ea814103c659682",
          "ClientSignatureUrl": null,
          "ClientSignerFullName": "Client 1",
          "ClientSignatureTransactionId": "4",
          "IsClientSigned": true,
          "ClientSignedOn": "06/15/2022 09:42 AM",
          "CanClientSign": true,
          "IsDocumentAwaitingReview": false,
          "BackToUrl": "/cases/progress-notes/627ed580564116fcc2e7b9c5",
          "BackToPageTitle": "Progress Notes",
          "IsMcpNonTherapistAdmin": false
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
        expect(ds.db).to be_table_exists(svc.qualified_table_sequel_identifier)
      end
      expect(sint.db).to_not be_table_exists(svc.qualified_table_sequel_identifier)
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

  it_behaves_like "a service implementation dependent on another", "theranest_progress_note_document_v1",
                  "theranest_progress_note_v1" do
    let(:no_dependencies_message) { "This integration requires Theranest Progress Notes to sync" }
  end

  describe "backfill process" do
    let(:page1_response) do
      <<~R
                {
          "Checksum": "md5a9b47a8d00186143f4f687060b6c346e",
          "DocumentId": "doc_abc123",
          "AppointmentId": null,
          "HasLinkedAppointment": false,
          "ClientId": "client1",
          "IsNoteSigned": true,
          "PdfUrl": "https://theraneststaging.theranest.com/api/signature/getSignedDocument/doc_abc123",
          "DownloadUrl": "/api/signature/downloadSignedDocument/doc_abc123",
          "IsCaseForm": false,
          "IsClientForm": false,
          "StaffSignerId": "623bb09367189f5667b325aa",
          "StaffSignatureUrl": "/api/signature/getSignatureImage/6275603b0141280c039ecbb6",
          "StaffSignerFullName": "Rob Galanakis",
          "StaffSignatureTransactionId": "3",
          "StaffSignedOn": "06/15/2022 09:42 AM",
          "IsStaffSigned": true,
          "ClientSignerId": "5f5d238c2ea814103c659682",
          "ClientSignatureUrl": null,
          "ClientSignerFullName": "Client 1",
          "ClientSignatureTransactionId": "4",
          "IsClientSigned": true,
          "ClientSignedOn": "06/15/2022 09:42 AM",
          "CanClientSign": true,
          "IsDocumentAwaitingReview": false,
          "BackToUrl": "/cases/progress-notes/627ed580564116fcc2e7b9c5",
          "BackToPageTitle": "Progress Notes",
          "IsMcpNonTherapistAdmin": false
        }
      R
    end
    let(:page2_response) do
      <<~R
                                {
          "Checksum": "md5a9b47a8d00186143f4f687060b6c346e",
          "DocumentId": "doc_def456",
          "AppointmentId": null,
          "HasLinkedAppointment": false,
          "ClientId": "client2",
          "IsNoteSigned": true,
          "PdfUrl": "https://theraneststaging.theranest.com/api/signature/getSignedDocument/doc_def456",
          "DownloadUrl": "/api/signature/downloadSignedDocument/doc_def456",
          "IsCaseForm": false,
          "IsClientForm": false,
          "StaffSignerId": "623bb09367189f5667b325aa",
          "StaffSignatureUrl": "/api/signature/getSignatureImage/6275603b0141280c039ecbb6",
          "StaffSignerFullName": "Rob Galanakis",
          "StaffSignatureTransactionId": "3",
          "StaffSignedOn": "06/15/2022 09:42 AM",
          "IsStaffSigned": true,
          "ClientSignerId": "5f5d238c2ea814103c659682",
          "ClientSignatureUrl": null,
          "ClientSignerFullName": "Client 1",
          "ClientSignatureTransactionId": "4",
          "IsClientSigned": true,
          "ClientSignedOn": "06/15/2022 09:42 AM",
          "CanClientSign": true,
          "IsDocumentAwaitingReview": false,
          "BackToUrl": "/cases/progress-notes/627ed580564116fcc2e7b9c5",
          "BackToPageTitle": "Progress Notes",
          "IsMcpNonTherapistAdmin": false
        }
      R
    end

    before(:each) do
      org.prepare_database_connections
      auth_svc.create_table
      client_svc.create_table
      case_svc.create_table
      pnote_svc.create_table
      svc.create_table
      insert_progress_note_rows
    end

    after(:each) do
      org.remove_related_database
    end

    def stub_get_doc_id_requests
      return [
        stub_request(:get, "https://fake-url.com/api/sign/getNote?caseId=case_id&noteId=#{pnote_id_one}").
            to_return(status: 200, body: "doc_abc123".to_json, headers: {"Content-Type" => "application/json"}),
        stub_request(:get, "https://fake-url.com/api/sign/getNote?caseId=case_id&noteId=#{pnote_id_two}").
            to_return(status: 200, body: "doc_def456".to_json, headers: {"Content-Type" => "application/json"}),
      ]
    end

    def stub_service_requests
      return [
        stub_request(:get, "https://fake-url.com/api/sign/getDocumentView/doc_abc123").
            to_return(status: 200, body: page1_response, headers: {"Content-Type" => "application/json"}),
        stub_request(:get, "https://fake-url.com/api/sign/getDocumentView/doc_def456").
            to_return(status: 200, body: page2_response, headers: {"Content-Type" => "application/json"}),
      ]
    end

    def stub_service_request_error
      return stub_request(:get, "https://fake-url.com/api/sign/getDocumentView/doc_abc123").
          to_return(status: 503, body: "uhh")
    end

    it "inserts records for pages of results" do
      # this implicitly tests that the service integration can insert into its table
      responses = stub_get_doc_id_requests + stub_service_requests
      svc.backfill
      expect(responses).to all(have_been_made)
      rows = svc.readonly_dataset(&:all)
      expect(rows).to have_length(2)
      expect(rows).to contain_exactly(
        include(external_id: "doc_abc123"),
        include(external_id: "doc_def456"),
      )
    end

    it "errors if fetching page errors" do
      expect(Webhookdb::Backfiller).to receive(:do_retry_wait).twice # Mock out the sleep
      stub_get_doc_id_requests
      response = stub_service_request_error
      expect { svc.backfill }.to raise_error(Webhookdb::Http::Error)
      expect(response).to have_been_made.at_least_once
    end

    it "emits the rowupsert event", :async, :do_not_defer_events do
      body = JSON.parse(<<~J)
                {
          "Checksum": "md5a9b47a8d00186143f4f687060b6c346e",
          "DocumentId": "doc_def456",
          "AppointmentId": null,
          "HasLinkedAppointment": false,
          "ClientId": "client2",
          "IsNoteSigned": true,
          "PdfUrl": "https://theraneststaging.theranest.com/api/signature/getSignedDocument/doc_def456",
          "DownloadUrl": "/api/signature/downloadSignedDocument/doc_def456",
          "IsCaseForm": false,
          "IsClientForm": false,
          "StaffSignerId": "623bb09367189f5667b325aa",
          "StaffSignatureUrl": "/api/signature/getSignatureImage/6275603b0141280c039ecbb6",
          "StaffSignerFullName": "Rob Galanakis",
          "StaffSignatureTransactionId": "3",
          "StaffSignedOn": "06/15/2022 09:42 AM",
          "IsStaffSigned": true,
          "ClientSignerId": "5f5d238c2ea814103c659682",
          "ClientSignatureUrl": null,
          "ClientSignerFullName": "Client 1",
          "ClientSignatureTransactionId": "4",
          "IsClientSigned": true,
          "ClientSignedOn": "06/15/2022 09:42 AM",
          "CanClientSign": true,
          "IsDocumentAwaitingReview": false,
          "BackToUrl": "/cases/progress-notes/627ed580564116fcc2e7b9c5",
          "BackToPageTitle": "Progress Notes",
          "IsMcpNonTherapistAdmin": false
        }
      J
      Webhookdb::Fixtures.webhook_subscription(service_integration: sint).create
      expect(Webhookdb::Jobs::SendWebhook).to receive(:perform_async).
        with(include(
               "payload" => match_array([sint.id, hash_including("row", "external_id", "external_id_column")]),
             ))
      # this integration has no exact equivalent for `upsert_webhook`. `handle_item` mimics its functionality.
      backfiller = Webhookdb::Services::TheranestProgressNoteDocumentV1::ProgressNoteDocumentBackfiller.new(
        progress_note_document_svc: svc,
        theranest_case_id: "case_id_one",
        theranest_progress_note_id: pnote_id_one,
      )
      backfiller.handle_item(body)
    end
  end

  describe "state machine calculation" do
    describe "calculate_create_state_machine" do
      it "prompts for dependencies" do
        sint.update(depends_on: nil)
        pnote_sint.destroy
        sm = sint.calculate_create_state_machine
        expect(sm).to have_attributes(
          output: match("This integration requires Theranest Progress Notes to sync"),
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
          output: match("We will start backfilling Theranest Progress Note Document").
                    and(match("you can query Theranest Progress Note Documents")),
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
