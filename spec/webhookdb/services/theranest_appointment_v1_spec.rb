# frozen_string_literal: true

require "support/shared_examples_for_services"

RSpec.describe Webhookdb::Services::TheranestAppointmentV1, :db do
  let(:org) { Webhookdb::Fixtures.organization.create }
  let(:fac) { Webhookdb::Fixtures.service_integration(organization: org) }
  let(:auth) do
    fac.create(service_name: "theranest_auth_v1", api_url: "https://auth-api-url.com", backfill_key: "username",
               backfill_secret: "password",)
  end
  let(:sint) { fac.depending_on(auth).create(service_name: "theranest_appointment_v1").refresh }
  let(:svc) { sint.service_instance }

  def auth_stub_request
    return stub_request(:post, "https://auth-api-url.com/home/signin").to_return(
      status: 200,
      headers: {"Set-Cookie" => "new_cookie"},
    )
  end

  before(:each) do
    auth_stub_request
  end

  it_behaves_like "a service implementation", "theranest_appointment_v1" do
    let(:body) do
      JSON.parse(<<~J)
                {
           "!nativeeditor_status":null,
           "actual_end_date":null,
           "actual_start_date":null,
           "allClientsIds":[
              "60341d7b41ec8113b47e8193"
           ],
           "allStaffMembersIds":[
              "623bb09367189f5667b325aa"
           ],
           "badgeCssClass":"",
           "clientNames":null,
           "client_contacts":"",
           "client_id":"60341d7b41ec8113b47e8193",
           "coPayAmount":null,
           "color":"#1796b0",
           "currentUserHasAccessToDetails":true,
           "end_date":"06/10/2022 12:30",
           "event_length":"",
           "event_pid":null,
           "group":null,
           "group_id":null,
           "id":"abc123",
           "isAfterHours":false,
           "isAuthErrorApproved":false,
           "isBilled":false,
           "isEvent":"false",
           "isImmutable":false,
           "isMultiStaff":false,
           "isNonBillable":false,
           "isRelatedToCatalyst":false,
           "isRelatedToImmutableProgressNote":false,
           "isRepeating":false,
           "isTeletherapy":false,
           "linkToNote":null,
           "locationId":"1",
           "mileage":null,
           "notes":"",
           "originalAppointmentDisplayName":null,
           "originalAppointmentId":null,
           "reasonOfImpossibilityToStartOrJoinSession":null,
           "rec_pattern":"",
           "rec_type":"",
           "rescheduledToAppointmentDisplayName":null,
           "rescheduledToAppointmentId":null,
           "roomId":null,
           "roomShortName":null,
           "serviceType":"Q3014: Telehealth originating site facility fee",
           "serviceTypeIds":[
              "5f5d23004f3e2c0b1c358ca1"
           ],
           "stColor":"#333333",
           "stTextColor":"#FFFFFF",
           "staffMemberId":"623bb09367189f5667b325aa",
           "staffMemberIds":null,
           "start_date":"06/10/2022 11:30",
           "status":{
              "AbsenceReason":null,
              "IsAfterHoursOverride":false,
              "RescheduleToAppointmentId":null,
              "RescheduleToEndDate":null,
              "RescheduleToStartDate":null,
              "Status":"Upcoming"
           },
           "statusBadge":"",
           "statusJson":"{\\"Status\\":\\"Upcoming\\",\\"AbsenceReason\\":null,\\"RescheduleToAppointmentId\\":null,\\"RescheduleToStartDate\\":null,\\"RescheduleToEndDate\\":null,\\"IsAfterHoursOverride\\":false}",
           "teletherapyInternalToken":null,
           "teletherapySessionId":null,
           "teletherapyTitle":null,
           "textColor":"#ffffff",
           "title":"Sid Cidambi",
           "type":1
        }
      J
    end
    let(:supports_row_diff) { false }
  end

  it_behaves_like "a service implementation dependent on another", "theranest_appointment_v1", "theranest_auth_v1" do
    let(:no_dependencies_message) { "This integration requires Theranest Auth to sync" }
  end

  it_behaves_like "a service implementation that can backfill", "theranest_appointment_v1" do
    let(:page1_response) do
      <<~R
                [
          {
            "!nativeeditor_status": null,
            "actual_end_date": null,
            "actual_start_date": null,
            "allClientsIds": [
              "60341d7b41ec8113b47e8193"
            ],
            "allStaffMembersIds": [
              "623bb09367189f5667b325aa"
            ],
            "badgeCssClass": "",
            "clientNames": null,
            "client_contacts": "",
            "client_id": "60341d7b41ec8113b47e8193",
            "coPayAmount": null,
            "color": "#1796b0",
            "currentUserHasAccessToDetails": true,
            "end_date": "06\/10\/2022 12:30",
            "event_length": "",
            "event_pid": null,
            "group": null,
            "group_id": null,
            "id": "abc123",
            "isAfterHours": false,
            "isAuthErrorApproved": false,
            "isBilled": false,
            "isEvent": "false",
            "isImmutable": false,
            "isMultiStaff": false,
            "isNonBillable": false,
            "isRelatedToCatalyst": false,
            "isRelatedToImmutableProgressNote": false,
            "isRepeating": false,
            "isTeletherapy": false,
            "linkToNote": null,
            "locationId": "1",
            "mileage": null,
            "notes": "",
            "originalAppointmentDisplayName": null,
            "originalAppointmentId": null,
            "reasonOfImpossibilityToStartOrJoinSession": null,
            "rec_pattern": "",
            "rec_type": "",
            "rescheduledToAppointmentDisplayName": null,
            "rescheduledToAppointmentId": null,
            "roomId": null,
            "roomShortName": null,
            "serviceType": "Q3014: Telehealth originating site facility fee",
            "serviceTypeIds": [
              "5f5d23004f3e2c0b1c358ca1"
            ],
            "stColor": "#333333",
            "stTextColor": "#FFFFFF",
            "staffMemberId": "623bb09367189f5667b325aa",
            "staffMemberIds": null,
            "start_date": "06\/10\/2022 11:30",
            "status": {
              "AbsenceReason": null,
              "IsAfterHoursOverride": false,
              "RescheduleToAppointmentId": null,
              "RescheduleToEndDate": null,
              "RescheduleToStartDate": null,
              "Status": "Upcoming"
            },
            "statusBadge": "",
            "statusJson": "{\\"Status\\":\\"Upcoming\\",\\"AbsenceReason\\":null,\\"RescheduleToAppointmentId\\":null,\\"RescheduleToStartDate\\":null,\\"RescheduleToEndDate\\":null,\\"IsAfterHoursOverride\\":false}",
            "teletherapyInternalToken": null,
            "teletherapySessionId": null,
            "teletherapyTitle": null,
            "textColor": "#ffffff",
            "title": "Sid Cidambi",
            "type": 1
          },
          {
            "!nativeeditor_status": null,
            "actual_end_date": null,
            "actual_start_date": null,
            "allClientsIds": [
              "623bb7d3c71e39b79133efe7"
            ],
            "allStaffMembersIds": [
              "623bb09367189f5667b325aa"
            ],
            "badgeCssClass": "",
            "clientNames": null,
            "client_contacts": "",
            "client_id": "623bb7d3c71e39b79133efe7",
            "coPayAmount": null,
            "color": "#1796b0",
            "currentUserHasAccessToDetails": true,
            "end_date": "06\/09\/2022 11:00",
            "event_length": "",
            "event_pid": null,
            "group": null,
            "group_id": null,
            "id": "def456",
            "isAfterHours": false,
            "isAuthErrorApproved": false,
            "isBilled": false,
            "isEvent": "false",
            "isImmutable": false,
            "isMultiStaff": false,
            "isNonBillable": false,
            "isRelatedToCatalyst": false,
            "isRelatedToImmutableProgressNote": false,
            "isRepeating": false,
            "isTeletherapy": false,
            "linkToNote": null,
            "locationId": "1",
            "mileage": null,
            "notes": "",
            "originalAppointmentDisplayName": null,
            "originalAppointmentId": null,
            "reasonOfImpossibilityToStartOrJoinSession": null,
            "rec_pattern": "",
            "rec_type": "",
            "rescheduledToAppointmentDisplayName": null,
            "rescheduledToAppointmentId": null,
            "roomId": null,
            "roomShortName": null,
            "serviceType": "90846: Family psychotherapy (without the patient present)",
            "serviceTypeIds": [
              "5f5d22ff4f3e2c0b1c358c91"
            ],
            "stColor": "#333333",
            "stTextColor": "#FFFFFF",
            "staffMemberId": "623bb09367189f5667b325aa",
            "staffMemberIds": null,
            "start_date": "06\/09\/2022 10:00",
            "status": {
              "AbsenceReason": null,
              "IsAfterHoursOverride": false,
              "RescheduleToAppointmentId": null,
              "RescheduleToEndDate": null,
              "RescheduleToStartDate": null,
              "Status": "Kept"
            },
            "statusBadge": "",
            "statusJson": "{\\"Status\\":\\"Kept\\",\\"AbsenceReason\\":null,\\"RescheduleToAppointmentId\\":null,\\"RescheduleToStartDate\\":null,\\"RescheduleToEndDate\\":null,\\"IsAfterHoursOverride\\":false}",
            "teletherapyInternalToken": null,
            "teletherapySessionId": null,
            "teletherapyTitle": null,
            "textColor": "#ffffff",
            "title": "Rob GalanakisClient",
            "type": 1
          }
        ]
      R
    end
    let(:expected_items_count) { 2 }

    def stub_auth_request
      return stub_request(:post, "https://auth-api-url.com/home/signin").
          to_return(status: 200, body: "", headers: {})
    end

    def stub_service_requests
      return [
        stub_request(:post, "https://auth-api-url.com/api/appointments/getAppointments").
            to_return(status: 200, body: page1_response, headers: {"Content-Type" => "application/json"}),
      ]
    end

    def stub_service_request_error
      return stub_request(:post, "https://auth-api-url.com/api/appointments/getAppointments").
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
        auth.destroy
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
          output: match("start backfilling Theranest Appointment").and(match("you can query Theranest Appointments")),
        )
      end
    end
  end

  describe "mixin methods" do
    let(:org) { Webhookdb::Fixtures.organization.create }
    let(:fac) { Webhookdb::Fixtures.service_integration(organization: org) }
    let(:auth) { fac.create(service_name: "theranest_auth_v1") }
    let(:sint) { fac.depending_on(auth).create(service_name: "theranest_appointment_v1").refresh }

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
