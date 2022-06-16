# frozen_string_literal: true

require "support/shared_examples_for_services"

RSpec.describe Webhookdb::Services::TheranestAppointmentV1, :db do
  let(:org) { Webhookdb::Fixtures.organization.create }
  let(:fac) { Webhookdb::Fixtures.service_integration(organization: org) }
  let(:dependency) do
    fac.create(service_name: "theranest_auth_v1", api_url: "https://auth-api-url.com", backfill_key: "username",
               backfill_secret: "password",)
  end
  let(:dep_svc) { dependency.service_instance }
  let(:sint) { fac.depending_on(dependency).create(service_name: "theranest_appointment_v1").refresh }
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
    let(:expected_data) { body }
    let(:supports_row_diff) { false }
  end

  it_behaves_like "a service implementation dependent on another", "theranest_appointment_v1", "theranest_auth_v1" do
    let(:no_dependencies_message) { "This integration requires Theranest Auth to sync" }
  end

  it_behaves_like "a service implementation that uses enrichments", "theranest_appointment_v1" do
    let(:enrichment_tables) { svc.enrichment_tables }
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
              "type1",#{' '}
              "type2",#{' '}
              "type3"
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

    def stub_service_request
      # _fetch_enrichment does not make an HTTP request
      return nil
    end

    def stub_service_request_error
      # _fetch_enrichment does not make an HTTP request
      return nil
    end

    def assert_is_enriched(_row)
      # we are not enriching data within the table, so this can just return true
      return true
    end

    def assert_enrichment_after_insert(db)
      enrichment_table_sym = enrichment_tables[0].to_sym
      entries = db[enrichment_table_sym].all

      expect(entries).to have_length(3)
      expect(entries).to contain_exactly(
        include(theranest_appointment_id: "abc123", theranest_service_type_id: "type1"),
        include(theranest_appointment_id: "abc123", theranest_service_type_id: "type2"),
        include(theranest_appointment_id: "abc123", theranest_service_type_id: "type3"),
      )
    end
  end

  describe "_fetch_enrichment" do
    before(:each) do
      sint.organization.prepare_database_connections
      svc.create_table
    end

    after(:each) do
      sint.organization.remove_related_database
    end

    let(:sint) { Webhookdb::Fixtures.service_integration.create(service_name: "theranest_appointment_v1") }
    let(:svc) { Webhookdb::Services.service_instance(sint) }
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
              "type1",
              "type2"#{' '}
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

    it "returns expected information" do
      expect(svc._fetch_enrichment(body)).to contain_exactly("type1", "type2")
    end
  end

  describe "specialized enrichment behavior" do
    before(:each) do
      sint.organization.prepare_database_connections
    end

    after(:each) do
      sint.organization.remove_related_database
    end

    let(:sint) { Webhookdb::Fixtures.service_integration.create(service_name: "theranest_appointment_v1") }
    let(:svc) { Webhookdb::Services.service_instance(sint) }
    let(:enrichment_tables) { svc.enrichment_tables }
    let(:old_body) do
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
              "type1",
              "type2"#{' '}
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
    let(:new_body) do
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
              "type1",
              "type2",#{' '}
              "type3"
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

    it "will upsert based on appointment and service_type ids" do
      svc.create_table
      enrichment_table_sym = enrichment_tables[0].to_sym
      db = svc.readonly_dataset(&:db)

      svc.upsert_webhook(body: old_body)
      entries = db[enrichment_table_sym].all
      expect(entries).to have_length(2)
      expect(entries).to contain_exactly(
        include(theranest_appointment_id: "abc123", theranest_service_type_id: "type1"),
        include(theranest_appointment_id: "abc123", theranest_service_type_id: "type2"),
      )

      svc.upsert_webhook(body: new_body)
      entries = db[enrichment_table_sym].all
      expect(entries).to have_length(3)
      expect(entries).to contain_exactly(
        include(theranest_appointment_id: "abc123", theranest_service_type_id: "type1"),
        include(theranest_appointment_id: "abc123", theranest_service_type_id: "type2"),
        include(theranest_appointment_id: "abc123", theranest_service_type_id: "type3"),
      )
    end
  end

  describe "backfill process" do
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
        stub_request(:post, "https://auth-api-url.com/api/appointments/getAppointments").
            to_return(status: 200, body: page1_response, headers: {"Content-Type" => "application/json"}),
      ]
    end

    def stub_service_request_error
      return stub_request(:post, "https://auth-api-url.com/api/appointments/getAppointments").
          to_return(status: 503, body: "uhh")
    end

    it "inserts records for pages of results" do
      responses = stub_service_requests
      svc.backfill
      expect(responses).to all(have_been_made)
      rows = svc.readonly_dataset(&:all)
      expect(rows).to have_length(2)
      expect(rows).to contain_exactly(
        include(external_id: "abc123", status: "Upcoming"),
        include(external_id: "def456", status: "Kept"),
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
          output: match("start backfilling Theranest Appointment").and(match("you can query Theranest Appointments")),
        )
      end
    end
  end

  describe "mixin methods" do
    let(:org) { Webhookdb::Fixtures.organization.create }
    let(:fac) { Webhookdb::Fixtures.service_integration(organization: org) }
    let(:dependency) { fac.create(service_name: "theranest_auth_v1") }
    let(:sint) { fac.depending_on(dependency).create(service_name: "theranest_appointment_v1").refresh }

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
