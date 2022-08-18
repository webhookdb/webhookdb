# frozen_string_literal: true

require "support/shared_examples_for_services"

RSpec.describe Webhookdb::Services::TheranestClientV1, :db do
  let(:org) { Webhookdb::Fixtures.organization.create }
  let(:fac) { Webhookdb::Fixtures.service_integration(organization: org) }
  let(:auth) do
    fac.create(service_name: "theranest_auth_v1", api_url: "https://auth-api-url.com", backfill_key: "username",
               backfill_secret: "password",)
  end
  let(:sint) { fac.depending_on(auth).create(service_name: "theranest_client_v1").refresh }
  let(:svc) { sint.service_instance }

  def auth_stub_request
    return stub_request(:post, "https://auth-api-url.com/home/signin").to_return(
      status: 200,
      headers: {"Set-Cookie" => "new_cookie"},
    )
  end

  before(:each) do
    Webhookdb::Theranest.page_size = 1
    auth_stub_request
  end

  it_behaves_like "a service implementation", "theranest_client_v1" do
    let(:body) do
      JSON.parse(<<~J)
        {
            "Id": "60e3d6ff41ec8e1788c2b2e8",
            "IsArchived": false,
            "FullName": "(GPT1) Gad Phq Test 1",
            "FirstName": "Gad Phq",
            "MiddleName": "",
            "LastName": "Test 1",
            "PreferredName": "GPT1",
            "ClientIdNumber": "-",
            "DateOfBirthMDY": "04/07/2007",
            "DateOfBirthYMD": "2007/04/07",
            "DateOfBirthDMY": "07/04/2007",
            "MobilePhone": "-",
            "HomePhone": "-",
            "Email": "luke@daybreakhealth.com",
            "RegistrationDateTimeMDY": "07/06/2021",
            "RegistrationDateTimeYMD": "2021/07/06",
            "RegistrationDateTimeDMY": "06/07/2021",
            "IntakeDateMDY": "07/05/2021",
            "IntakeDateYMD": "2021/07/05",
            "IntakeDateDMY": "05/07/2021",
            "PrimaryPayer": "-",
            "SecondaryPayer": "-",
            "AssignedStaffString": "Luke Mercado",
            "AssignedStaffIds": [
                "5f5d22fd4f3e2c0b1c358c4f"
            ],
            "TotalKeptAppointments": "1",
            "FirstKeptAppointmentDateTimeMDY": "05/02/2022 10:00 AM",
            "FirstKeptAppointmentDateTimeYMD": "2022/05/02 10:00 AM",
            "FirstKeptAppointmentDateTimeDMY": "02/05/2022 10:00 AM",
            "FirstKeptAppointmentId": "627012888451ba86137578a6",
            "LastKeptAppointmentDateTimeMDY": "05/02/2022 10:00 AM",
            "LastKeptAppointmentDateTimeYMD": "2022/05/02 10:00 AM",
            "LastKeptAppointmentDateTimeDMY": "02/05/2022 10:00 AM",
            "LastKeptAppointmentId": "627012888451ba86137578a6",
            "NextAppointmentDateTimeMDY": "-",
            "NextAppointmentDateTimeYMD": "-",
            "NextAppointmentDateTimeDMY": "-",
            "NextAppointmentId": null,
            "HasVerifiedCards": false,
            "DoNotContactByPhoneCall": false,
            "DoNotContactBySms": false,
            "DoNotContactByEmail": false,
            "Age": "15",
            "ClientBalanceDue": 0,
            "InsuranceBalanceDue": 0,
            "TotalBalanceDue": 0,
            "CaseNotesUrl": "/cases/new/client-60e3d6ff41ec8e1788c2b2e8/redirect-progress-notes-list",
            "HasOpenTeletherapySessions": false,
            "Notes": null,
            "Location": "Primary Location",
            "LocationId": "1"
        }
      J
    end
    let(:supports_row_diff) { false }
  end

  it_behaves_like "a service implementation dependent on another", "theranest_client_v1", "theranest_auth_v1" do
    let(:no_dependencies_message) { "This integration requires Theranest Auth to sync" }
  end

  it_behaves_like "a service implementation that can backfill", "theranest_client_v1" do
    let(:page1_response) do
      <<~R
        {
            "Data": [
                {
                    "Id": "abc123",
                    "IsArchived": false,
                    "FullName": "Client 1",
                    "FirstName": "Client",
                    "MiddleName": "",
                    "LastName": "1",
                    "PreferredName": "",
                    "ClientIdNumber": "-",
                    "DateOfBirthMDY": "-",
                    "DateOfBirthYMD": "-",
                    "DateOfBirthDMY": "-",
                    "MobilePhone": "-",
                    "HomePhone": "-",
                    "Email": "client1@test.com",
                    "RegistrationDateTimeMDY": "09/12/2020",
                    "RegistrationDateTimeYMD": "2020/09/12",
                    "RegistrationDateTimeDMY": "12/09/2020",
                    "IntakeDateMDY": "09/12/2020",
                    "IntakeDateYMD": "2020/09/12",
                    "IntakeDateDMY": "12/09/2020",
                    "PrimaryPayer": "-",
                    "SecondaryPayer": "-",
                    "AssignedStaffString": "Luke Mercado",
                    "AssignedStaffIds": [
                        "5f5d22fd4f3e2c0b1c358c4f"
                    ],
                    "TotalKeptAppointments": "9",
                    "FirstKeptAppointmentDateTimeMDY": "04/23/2021 05:00 AM",
                    "FirstKeptAppointmentDateTimeYMD": "2021/04/23 05:00 AM",
                    "FirstKeptAppointmentDateTimeDMY": "23/04/2021 05:00 AM",
                    "FirstKeptAppointmentId": "60807b47459bf00f6880bd03",
                    "LastKeptAppointmentDateTimeMDY": "04/28/2022 11:00 AM",
                    "LastKeptAppointmentDateTimeYMD": "2022/04/28 11:00 AM",
                    "LastKeptAppointmentDateTimeDMY": "28/04/2022 11:00 AM",
                    "LastKeptAppointmentId": "623b6d7c7e779c95b375ff40",
                    "NextAppointmentDateTimeMDY": "05/05/2022 11:00 AM",
                    "NextAppointmentDateTimeYMD": "2022/05/05 11:00 AM",
                    "NextAppointmentDateTimeDMY": "05/05/2022 11:00 AM",
                    "NextAppointmentId": "623b6d7c7e779c95b375ff43",
                    "HasVerifiedCards": false,
                    "DoNotContactByPhoneCall": false,
                    "DoNotContactBySms": false,
                    "DoNotContactByEmail": false,
                    "Age": "-",
                    "ClientBalanceDue": 0,
                    "InsuranceBalanceDue": 0,
                    "TotalBalanceDue": 0,
                    "CaseNotesUrl": "/cases/new/client-5f5d238c2ea814103c659682/redirect-progress-notes-list",
                    "HasOpenTeletherapySessions": false,
                    "Notes": null,
                    "Location": "Primary Location",
                    "LocationId": "1"
                }
            ],
            "Paging": {
                "Page": 1,
                "ItemsPerPage": 1,
                "TotalPagesCount": 2,
                "TotalCount": 2,
                "Pages": [
                    {
                        "Value": null,
                        "Text": "1",
                        "IsSelected": true
                    },
                    {
                        "Value": null,
                        "Text": "2",
                        "IsSelected": false
                    },
                    {
                        "Value": null,
                        "Text": "3",
                        "IsSelected": false
                    }
                ],
                "HasPrev": false,
                "HasNext": true,
                "NextPage": 2,
                "PrevPage": null
            }
        }
      R
    end
    let(:page2_response) do
      <<~R
                {
            "Data": [
                {
                    "Id": "def456",
                    "IsArchived": false,
                    "FullName": "Client 2",
                    "FirstName": "Client",
                    "MiddleName": "",
                    "LastName": "2",
                    "PreferredName": "",
                    "ClientIdNumber": "-",
                    "DateOfBirthMDY": "02/13/2021",
                    "DateOfBirthYMD": "2021/02/13",
                    "DateOfBirthDMY": "13/02/2021",
                    "MobilePhone": "-",
                    "HomePhone": "-",
                    "Email": "client2@test.com",
                    "RegistrationDateTimeMDY": "09/12/2020",
                    "RegistrationDateTimeYMD": "2020/09/12",
                    "RegistrationDateTimeDMY": "12/09/2020",
                    "IntakeDateMDY": "09/12/2020",
                    "IntakeDateYMD": "2020/09/12",
                    "IntakeDateDMY": "12/09/2020",
                    "PrimaryPayer": "-",
                    "SecondaryPayer": "-",
                    "AssignedStaffString": "Luke Mercado",
                    "AssignedStaffIds": [
                        "5f5d22fd4f3e2c0b1c358c4f"
                    ],
                    "TotalKeptAppointments": "2",
                    "FirstKeptAppointmentDateTimeMDY": "04/27/2021 11:30 AM",
                    "FirstKeptAppointmentDateTimeYMD": "2021/04/27 11:30 AM",
                    "FirstKeptAppointmentDateTimeDMY": "27/04/2021 11:30 AM",
                    "FirstKeptAppointmentId": "60807b5e4f3e9a12dc81bb19",
                    "LastKeptAppointmentDateTimeMDY": "04/29/2021 04:00 PM",
                    "LastKeptAppointmentDateTimeYMD": "2021/04/29 04:00 PM",
                    "LastKeptAppointmentDateTimeDMY": "29/04/2021 04:00 PM",
                    "LastKeptAppointmentId": "608b1b969e2767023c114572",
                    "NextAppointmentDateTimeMDY": "-",
                    "NextAppointmentDateTimeYMD": "-",
                    "NextAppointmentDateTimeDMY": "-",
                    "NextAppointmentId": null,
                    "HasVerifiedCards": false,
                    "DoNotContactByPhoneCall": false,
                    "DoNotContactBySms": false,
                    "DoNotContactByEmail": false,
                    "Age": "1",
                    "ClientBalanceDue": 0,
                    "InsuranceBalanceDue": 0,
                    "TotalBalanceDue": 0,
                    "CaseNotesUrl": "/cases/new/client-5f5d23965ed301080861daad/redirect-progress-notes-list",
                    "HasOpenTeletherapySessions": false,
                    "Notes": null,
                    "Location": "Primary Location",
                    "LocationId": "1"
                }
            ],
            "Paging": {
                "Page": 1,
                "ItemsPerPage": 1,
                "TotalPagesCount": 2,
                "TotalCount": 2,
                "Pages": [
                    {
                        "Value": null,
                        "Text": "1",
                        "IsSelected": true
                    },
                    {
                        "Value": null,
                        "Text": "2",
                        "IsSelected": false
                    },
                    {
                        "Value": null,
                        "Text": "3",
                        "IsSelected": false
                    }
                ],
                "HasPrev": false,
                "HasNext": true,
                "NextPage": 2,
                "PrevPage": null
            }
        }
      R
    end
    let(:page3_response) do
      <<~R
                {
            "Data": [],
            "Paging": {
                "Page": 1,
                "ItemsPerPage": 1,
                "TotalPagesCount": 2,
                "TotalCount": 2,
                "Pages": [
                    {
                        "Value": null,
                        "Text": "1",
                        "IsSelected": true
                    },
                    {
                        "Value": null,
                        "Text": "2",
                        "IsSelected": false
                    },
                    {
                        "Value": null,
                        "Text": "3",
                        "IsSelected": false
                    }
                ],
                "HasPrev": false,
                "HasNext": true,
                "NextPage": 2,
                "PrevPage": null
            }
        }

      R
    end
    let(:expected_items_count) { 2 }

    def stub_auth_request
      return stub_request(:post, "https://auth-api-url.com/home/signin").
          to_return(status: 200, body: "", headers: {})
    end

    def stub_service_requests
      return [
        stub_request(:get, "https://auth-api-url.com/api/clients/listing?fullNameSort=asc&skip=0&take=1").
            to_return(status: 200, body: page1_response, headers: {"Content-Type" => "application/json"}),
        stub_request(:get, "https://auth-api-url.com/api/clients/listing?fullNameSort=asc&skip=1&take=1").
            to_return(status: 200, body: page2_response, headers: {"Content-Type" => "application/json"}),
        stub_request(:get, "https://auth-api-url.com/api/clients/listing?fullNameSort=asc&skip=2&take=1").
            to_return(status: 200, body: page3_response, headers: {"Content-Type" => "application/json"}),
      ]
    end

    def stub_service_request_error
      return stub_request(:get, "https://auth-api-url.com/api/clients/listing?fullNameSort=asc&skip=0&take=1").
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
          output: match("start backfilling Theranest Client").and(match("you can query Theranest Clients")),
        )
      end
    end
  end

  describe "mixin methods" do
    let(:org) { Webhookdb::Fixtures.organization.create }
    let(:fac) { Webhookdb::Fixtures.service_integration(organization: org) }
    let(:auth) { fac.create(service_name: "theranest_auth_v1") }
    let(:sint) { fac.depending_on(auth).create(service_name: "theranest_client_v1").refresh }

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
