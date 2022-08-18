# frozen_string_literal: true

require "support/shared_examples_for_services"

RSpec.describe Webhookdb::Services::TheranestProgressNoteDocumentV1, :db do
  let(:auth) do
    fac.create(service_name: "theranest_auth_v1",
               backfill_key: "username",
               backfill_secret: "password",
               api_url: "https://auth-api-url.com",)
  end
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
    return stub_request(:post, "https://auth-api-url.com/home/signin").to_return(
      status: 200,
      headers: {"Set-Cookie" => "new_cookie"},
    )
  end

  def insert_progress_note_rows(dep_svc)
    dep_svc.admin_dataset do |ds|
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

  it_behaves_like "a service implementation", "theranest_progress_note_document_v1" do
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
  end

  it_behaves_like "a service implementation dependent on another", "theranest_progress_note_document_v1",
                  "theranest_progress_note_v1" do
    let(:no_dependencies_message) { "This integration requires Theranest Progress Notes to sync" }
  end

  it_behaves_like "a service implementation that can backfill", "theranest_progress_note_document_v1" do
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
    let(:expected_items_count) { 2 }

    def stub_service_requests
      return [
        # these first two requests get the doc ids
        stub_request(:get, "https://auth-api-url.com/api/sign/getNote?caseId=case_id&noteId=#{pnote_id_one}").
            to_return(status: 200, body: "doc_abc123".to_json, headers: {"Content-Type" => "application/json"}),
        stub_request(:get, "https://auth-api-url.com/api/sign/getNote?caseId=case_id&noteId=#{pnote_id_two}").
            to_return(status: 200, body: "doc_def456".to_json, headers: {"Content-Type" => "application/json"}),
        # these second two requests get the information that we actually want
        stub_request(:get, "https://auth-api-url.com/api/sign/getDocumentView/doc_abc123").
            to_return(status: 200, body: page1_response, headers: {"Content-Type" => "application/json"}),
        stub_request(:get, "https://auth-api-url.com/api/sign/getDocumentView/doc_def456").
            to_return(status: 200, body: page2_response, headers: {"Content-Type" => "application/json"}),
      ]
    end

    def stub_service_request_error
      return stub_request(:get, "https://auth-api-url.com/api/sign/getNote?caseId=case_id&noteId=#{pnote_id_one}").
          to_return(status: 503, body: "uhh")
    end

    def insert_required_data_callback
      return ->(dep_svc) { insert_progress_note_rows(dep_svc) }
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
