# frozen_string_literal: true

require "support/shared_examples_for_services"

RSpec.describe Webhookdb::Services::TheranestProgressNoteV1, :db do
  let(:auth) do
    fac.create(service_name: "theranest_auth_v1",
               backfill_key: "username",
               backfill_secret: "password",
               api_url: "https://auth-api-url.com",)
  end
  let(:case1_id) { SecureRandom.hex(5) }
  let(:case2_id) { SecureRandom.hex(5) }
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
                          external_id: case1_id,
                          external_client_id: "client_id",
                          state: "open",
                        },
                        {
                          data: "{}",
                          external_id: case2_id,
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
      JSON.parse(<<~J)
        {
          "ClientId": "5f5d238c2ea814103c659682",
          "ClientFullName": "Client 1",
          "ClientNumber": "n/a",
          "ClientGroupId": null,
          "ClientGroupName": null,
          "NoteId": "634714d33741869e17c9db36",
          "CreationDate": "10/12/2022",
          "CreationTime": "12:25 PM",
          "ShowCreationDateTime": true,
          "Date": "10/12/2022",
          "Time": "12:25 PM",
          "DateTimeFormat": "MM/dd/yyyy hh:mm tt",
          "AssignedStaffIds": ["62ba50199440c0643cf76301"],
          "AssignableStaffs": {"62ba50199440c0643cf76301": "Chris VDW"},
          "AppointmentId": null,
          "Appointments": [],
          "Appearance": ["dirty"],
          "Affect": ["constricted"],
          "Sleep": ["middle insomnia"],
          "Appetite": ["erratic"],
          "Orientation": ["x1: person only"],
          "ThoughtProcess": ["disorganized"],
          "Judgement": ["intact"],
          "Insight": ["full"],
          "ThoughtContent": ["delusions: guilt, sin"],
          "Behavior": ["awkward"],
          "Speech": ["hesitant"],
          "Mood": ["anxious: mild"],
          "Perception": ["hallucinations: tactile"],
          "SessionFocus": "thi sis session",
          "TherapeuticIntervention": "theraputic intervention",
          "PlannedIntervention": "planned intervension is",
          "CatalystNotes": null,
          "Duration": 60,
          "AppearanceOptions": [],
          "AffectOptions": ["appropriate to situation"],
          "SleepOptions": ["early insomnia"],
          "AppetiteOptions": ["WNL"],
          "OrientationOptions": [],
          "ThoughtProcessOptions": ["WNL"],
          "JudgementOptions": ["WNL"],
          "InsightOptions": [],
          "ThoughtContentOptions": ["WNL"],
          "BehaviorOptions": ["WNL"],
          "SpeechOptions": ["WNL"],
          "MoodOptions": ["WNL"],
          "PerceptionOptions": ["WNL"],
          "Suicidality": ["Plan"],
          "Homicidality": ["Intent"],
          "RiskAssessmentNotes": "this is a longer risk assessment",
          "SuicidalityOptions": ["Attempt"],
          "HomicidalityOptions": ["Attempt"],
          "DiagnosticImpressions": [],
          "AllTreatmentGoals": [
            {
              "Title": "Treatment Goals",
              "PrintTitle": true,
              "IsExpanded": true,
              "HelpText": "Displays goals from most recently created treatment plan in this case.",
              "TreatmentGoals": [
                {
                  "Id": "62f7a718bc3ae2bb416c1415",
                  "Name": "",
                  "TargetCompletionDate": "",
                  "GoalTargetCompletionDateText": "n/a",
                  "Objectives": [],
                  "CaseId": "#{case2_id}",
                  "CaseName": null,
                  "IsClosed": false,
                  "IsGroupCase": false,
                  "IsAba": false
                },
                {
                  "Id": "62f7a729d678a7f60203c90f",
                  "Name": "test",
                  "TargetCompletionDate": "08/27/2022",
                  "GoalTargetCompletionDateText": "08/27/2022",
                  "Objectives": [
                    {
                      "Description": "test",
                      "Intervention": ["Accountability"],
                      "Targets": [],
                      "TargetCompletionDate": "08/27/2022",
                      "ObjectiveTargetCompletionDateText": "08/27/2022",
                      "Status": "InProgress",
                      "InterventionStr": "Accountability",
                      "TargetsStr": ""
                    }
                  ],
                  "CaseId": "#{case2_id}",
                  "CaseName": null,
                  "IsClosed": false,
                  "IsGroupCase": false,
                  "IsAba": false
                }
              ]
            }
          ],
          "ActiveMedications": null,
          "UserHasReadonlyAccessToRcopia": false,
          "MedicationsListNeeded": false,
          "SignId": null,
          "IsSigned": false,
          "IsAwaitingReview": false,
          "IsApproved": false,
          "CanBeSigned": true,
          "CanBeUnSigned": false,
          "CanBeApproved": false,
          "IsReadOnlyWileyProgressNoteForCurrentStaff": false,
          "IsReadOnly": false,
          "AddGoalsUrl": "/cases/#{case2_id}/treatment-plan/62d76cb33a75ed6b45cd8019",
          "ApplyToAllClientsInCase": false,
          "PlaceOfServiceCode": "11",
          "RelatedInvoicePlaceOfServiceCode": null,
          "PlacesOfService": [
            {
              "Value": "13",
              "Text": "Assisted Living Facility (13)",
              "IsSelected": false,
              "IsPopulated": true,
              "IsDisabled": false
            }
          ],
          "CanEditPlaceOfService": true,
          "RelatedInvoiceId": null,
          "Addendums": [],
          "DefaultProgressNoteTemplate": 0,
          "DynamicProgressNoteTemplate": "624380cb2222492ddd1eb4a0",
          "DefaultProgressNoteSettings": {
            "DefaultProgressNoteTemplateType": "StandardNote",
            "ProgressNoteTemplateTypes": null,
            "IsDiagnosticImpressionsEnable": true,
            "IsCurrentTreatmentGoalsEnable": true,
            "IsTreatmentGoalHistoryEnable": true,
            "IsSessionFocusEnable": true,
            "IsTherapeuticInterventionEnable": true,
            "IsPlannedInterventionEnable": true,
            "IsActiveMedicationsEnable": true,
            "IsEPrescriptionsEnabled": false,
            "IsTypeOfNoteEnable": false,
            "IsParticipantInSessionEnable": false,
            "IsSubjectiveEnable": false,
            "IsObjectiveEnable": false,
            "IsAssessmentEnable": false,
            "IsPlanEnable": false,
            "IsAdditionalNotesEnable": false,
            "IsClientProgressEnable": false,
            "MentalStatusSettings": {
              "IsAppearanceEnable": true,
              "IsOrientationEnable": true,
              "IsBehaviorEnable": true,
              "IsSpeechEnable": true,
              "IsAffectEnable": true,
              "IsMoodEnable": true,
              "IsThoughtProcessEnable": true,
              "IsThoughtContentEnable": true,
              "IsPerceptionEnable": true,
              "IsJudgementEnable": true,
              "IsInsightEnable": true,
              "IsAppetiteEnable": true,
              "IsSleepEnable": true
            },
            "RiskAssessmentSettings": {
              "IsSuicidalityEnable": true,
              "IsHomicidalityEnable": true,
              "IsRiskAssessmentNotesEnable": true
            }
          },
          "ProgressNoteTypes": [
            {
              "Value": "Individual",
              "Text": "Individual",
              "IsSelected": false,
              "IsPopulated": true,
              "IsDisabled": false
            }
          ],
          "IsRelatedToCatalyst": false,
          "IsCatalystPdfImported": false,
          "TypeOfNote": "Individual",
          "ParticipantsInSession": null,
          "Subjective": null,
          "Objective": null,
          "Assessment": null,
          "Plan": null,
          "AdditionalNotes": null,
          "HasClientProgress": null,
          "ClientProgressAdditionalDetails": null,
          "Schema": {
            "Columns": [
              {
                "Elements": [
                  {
                    "Id": "624380cb2222492ddd1eb4a2",
                    "Title": null,
                    "Type": "RiskAssessment",
                    "Properties": {
                      "IsSuicidalityEnable": true,
                      "IsHomicidalityEnable": true,
                      "IsRiskAssessmentNotesEnable": true
                    }
                  }
                ]
              },
              {
                "Elements": [
                  {
                    "Id": "624380cb2222492ddd1eb4a3",
                    "Title": null,
                    "Type": "DiagnosticImpressions",
                    "Properties": {}
                  }
                ]
              }
            ]
          },
          "Input": {
            "624380cb2222492ddd1eb4a1": null
          },
          "InputNumber": null,
          "CaseId": "#{case2_id}",
          "CaseName": "Client 1",
          "IsClosed": false,
          "IsGroupCase": false,
          "IsAba": false
        }
      J
    end
  end

  it_behaves_like "a service implementation dependent on another", "theranest_progress_note_v1", "theranest_case_v1" do
    let(:no_dependencies_message) { "This integration requires Theranest Cases to sync" }
  end

  it_behaves_like "a service implementation that can backfill", "theranest_progress_note_v1" do
    let(:note1_id) { "note1" }
    let(:note2_id) { "note2" }
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
              "NoteId": "#{note1_id}",
              "CaseId": "#{case1_id}",
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
          "CaseId": "#{case1_id}",
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
              "NoteId": "#{note2_id}",
              "CaseId": "#{case2_id}",
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
          "CaseId": "#{case2_id}",
          "CaseName": null,
          "IsClosed": false,
          "IsGroupCase": false,
          "IsAba": false
        }
      R
    end

    def slim_note(caseid, noteid)
      <<~J
        {
          "ClientId": "client_id",
          "NoteId": "#{noteid}",
          "CreationDate": "10/12/2022",
          "CreationTime": "12:25 PM",
          "DateTimeFormat": "MM/dd/yyyy hh:mm tt",
          "CaseId": "#{caseid}"
        }
      J
    end

    let(:expected_items_count) { 2 }

    def insert_required_data_callback
      return ->(dep_svc) { insert_case_rows(dep_svc) }
    end

    def stub_service_requests
      apiroot = "https://auth-api-url.com/api"
      return [
        stub_request(:get, apiroot + "/cases/get-progress-notes-list?caseId=#{case1_id}").
            to_return(status: 200, body: page1_response, headers: json_headers),
        stub_request(:get, apiroot + "/cases/get-progress-notes-list?caseId=#{case2_id}").
            to_return(status: 200, body: page2_response, headers: json_headers),
        stub_request(:get, apiroot +
          "/cases/get-progress-note?caseId=#{case1_id}&clientId=client_id&noteId=#{note1_id}" \
          "&appointmentId=&templateId=",).
            to_return(status: 200, body: slim_note(case1_id, note1_id), headers: json_headers),
        stub_request(:get, apiroot +
          "/cases/get-progress-note?caseId=#{case2_id}&clientId=client_id&noteId=#{note2_id}" \
          "&appointmentId=&templateId=",).
            to_return(status: 200, body: slim_note(case2_id, note2_id), headers: json_headers),
      ]
    end

    def stub_service_request_error
      return stub_request(:get, "https://auth-api-url.com/api/cases/get-progress-notes-list?caseId=#{case1_id}").
          to_return(status: 503, body: "uhh")
    end
  end

  describe "specialized upsert behavior" do
    before(:each) do
      sint.organization.prepare_database_connections
    end

    after(:each) do
      sint.organization.remove_related_database
    end

    it "concats the creation date and time fields into a single timestamp" do
      body = {
        "ClientId" => "client_id",
        "NoteId" => "mynote",
        "CreationDate" => "10/12/2022",
        "CreationTime" => "12:25 PM",
        "DateTimeFormat" => "MM/dd/yyyy hh:mm tt",
        "CaseId" => "mycase",
      }
      svc.create_table
      svc.upsert_webhook_body(body)
      svc.readonly_dataset do |ds|
        expect(ds.all).to have_length(1)
        expect(ds.first[:theranest_created_at]).to match_time("2022-10-12T12:25:00-0700")
      end
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
