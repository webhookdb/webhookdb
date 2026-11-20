# frozen_string_literal: true

require "support/shared_examples_for_replicators"

RSpec.describe Webhookdb::Replicator::JotformWebhookV1, :db do
  # rubocop:disable Layout/LineLength
  it_behaves_like "a replicator", supports_row_diff: false do
    let(:raw_request) do
      {
        slug: "submit/5555",
        jsExecutionTracker: "build-date-1753686119291=>init-started:1753686122115=>validator-called:1753686122118=>validator-mounted-false:1753686122118=>init-complete:1753686122129=>interval-complete:1753686143210=>onsubmit-fired:1753686154613=>observerSubmitHandler_received-submit-event:1753686154613=>submit-validation-passed:1753686154617=>observerSubmitHandler_validation-passed-submitting-form:1753686154620=>init-started:1753687259482=>validator-called:1753687259484=>validator-mounted-false:1753687259484=>init-complete:1753687259486=>onsubmit-fired:1753687273822=>observerSubmitHandler_received-submit-event:1753687273823=>submit-validation-passed:1753687273827=>observerSubmitHandler_validation-passed-submitting-form:1753687273832=>init-started:1753713135766=>validator-called:1753713135768=>validator-mounted-false:1753713135768=>init-complete:1753713135770=>onsubmit-fired:1753713144922=>observerSubmitHandler_received-submit-event:1753713144922=>submit-validation-passed:1753713144929=>observerSubmitHandler_validation-passed-submitting-form:1753713144931",
        submitSource: "form",
        submitDate: "1753713144931",
        buildDate: "1753686119291",
        uploadServerUrl: "https://upload.jotform.com/upload",
        eventObserver: "1",
        q4_password: "somepassword2",
        q6_school: "",
        q7_schooltext: "newschool",
        q16_headerText: "",
        q17_routeMap: "",
        q11_contactEmail: "",
        q13_instagram: "",
        q14_bluesky: "",
        event_id: "1753713135766_5555_a4qAzSy",
        timeToSubmit: "9",
        temp_upload: {
          q8_headerImage: [
            "Screenshot 2025-07-03 at 08.07.58.png#jotformfs-bc35e2a4de105#01985172-ea2d-7152-9f75-6709ddd50aed",
          ],
        },
        file_server: "jotformfs-bc35e2a4de105#01985172-ea2d-7152-9f75-6709ddd50aed",
        validatedNewRequiredFieldIDs: "{\"new\":1}",
        path: "/submit/5555",
        headerImage: [
          "https://www.jotform.com/uploads/RobG/5555/6295223450435068292/Screenshot%202025-07-03%20at%2008.07.58.png",
        ],
      }.as_json
    end
    let(:body) do
      {
        action: "",
        webhookURL: "https://localhost:18001/v1/service_integrations_sv1_123",
        username: "RobG",
        formID: "5555",
        type: "WEB",
        customParams: "",
        product: "",
        formTitle: "Bike Bus PDX Website updater",
        customTitle: "",
        submissionID: "6295223450435068292",
        event: "",
        documentID: "",
        teamID: "",
        subject: "",
        isSilent: "",
        customBody: "",
        rawRequest: raw_request.to_json,
        fromTable: "",
        appID: "",
        pretty: "What is the password?:somepassword2, If not listed, add a new school.:newschool, Header Image:Screenshot 2025-07-03 at 08.07.58.png",
        unread: "",
        parent: "",
        ip: "73.96.87.240",
      }.as_json
    end
    let(:expected_row) do
      include(
        build_date: match_time("2025-07-28 07:01:59Z"),
        data: hash_including("action" => "", "rawRequest" => be_a(Hash)),
        event_id: "1753713135766_5555_a4qAzSy",
        form_id: "5555",
        inserted_at: match_time(:now),
        questions: hash_including(
          "bluesky" => "",
          "contactEmail" => "",
          "headerImage" => ["https://www.jotform.com/uploads/RobG/5555/6295223450435068292/Screenshot%202025-07-03%20at%2008.07.58.png"],
          "headerText" => "",
          "instagram" => "",
          "password" => "somepassword2",
          "routeMap" => "",
          "school" => "",
          "schooltext" => "newschool",
        ),
        submission_id: "6295223450435068292",
        submit_date: match_time("2025-07-28 14:32:24Z"),
      )
    end
  end

  describe "with a multipart/form-data body" do
    it_behaves_like "a replicator", supports_row_diff: false do
      let(:body) do
        "--------------------------rDBjFty9dvsCZSUvKYrKRh\r\nContent-Disposition: form-data; name=\"action\"\r\n\r\n\r\n--------------------------rDBjFty9dvsCZSUvKYrKRh\r\nContent-Disposition: form-data; name=\"webhookURL\"\r\n\r\nhttps://rgalanakis.ngrok.io/v1/service_integrations/svi_96glu7fqmrsgrd04waswnll39\r\n--------------------------rDBjFty9dvsCZSUvKYrKRh\r\nContent-Disposition: form-data; name=\"username\"\r\n\r\nRobG\r\n--------------------------rDBjFty9dvsCZSUvKYrKRh\r\nContent-Disposition: form-data; name=\"formID\"\r\n\r\n5555\r\n--------------------------rDBjFty9dvsCZSUvKYrKRh\r\nContent-Disposition: form-data; name=\"type\"\r\n\r\nWEB\r\n--------------------------rDBjFty9dvsCZSUvKYrKRh\r\nContent-Disposition: form-data; name=\"customParams\"\r\n\r\n\r\n--------------------------rDBjFty9dvsCZSUvKYrKRh\r\nContent-Disposition: form-data; name=\"product\"\r\n\r\n\r\n--------------------------rDBjFty9dvsCZSUvKYrKRh\r\nContent-Disposition: form-data; name=\"formTitle\"\r\n\r\nBike Bus PDX Website updater\r\n--------------------------rDBjFty9dvsCZSUvKYrKRh\r\nContent-Disposition: form-data; name=\"customTitle\"\r\n\r\n\r\n--------------------------rDBjFty9dvsCZSUvKYrKRh\r\nContent-Disposition: form-data; name=\"submissionID\"\r\n\r\n6295760960429644172\r\n--------------------------rDBjFty9dvsCZSUvKYrKRh\r\nContent-Disposition: form-data; name=\"event\"\r\n\r\n\r\n--------------------------rDBjFty9dvsCZSUvKYrKRh\r\nContent-Disposition: form-data; name=\"documentID\"\r\n\r\n\r\n--------------------------rDBjFty9dvsCZSUvKYrKRh\r\nContent-Disposition: form-data; name=\"teamID\"\r\n\r\n\r\n--------------------------rDBjFty9dvsCZSUvKYrKRh\r\nContent-Disposition: form-data; name=\"subject\"\r\n\r\n\r\n--------------------------rDBjFty9dvsCZSUvKYrKRh\r\nContent-Disposition: form-data; name=\"isSilent\"\r\n\r\n\r\n--------------------------rDBjFty9dvsCZSUvKYrKRh\r\nContent-Disposition: form-data; name=\"customBody\"\r\n\r\n\r\n--------------------------rDBjFty9dvsCZSUvKYrKRh\r\nContent-Disposition: form-data; name=\"rawRequest\"\r\n\r\n{\"slug\":\"submit\\/5555\",\"jsExecutionTracker\":\"build-date-1753686119291=>init-started:1753686122115=>validator-called:1753686122118=>validator-mounted-false:1753686122118=>init-complete:1753686122129=>interval-complete:1753686143210=>onsubmit-fired:1753686154613=>observerSubmitHandler_received-submit-event:1753686154613=>submit-validation-passed:1753686154617=>observerSubmitHandler_validation-passed-submitting-form:1753686154620=>init-started:1753687259482=>validator-called:1753687259484=>validator-mounted-false:1753687259484=>init-complete:1753687259486=>onsubmit-fired:1753687273822=>observerSubmitHandler_received-submit-event:1753687273823=>submit-validation-passed:1753687273827=>observerSubmitHandler_validation-passed-submitting-form:1753687273832=>init-started:1753713135766=>validator-called:1753713135768=>validator-mounted-false:1753713135768=>init-complete:1753713135770=>onsubmit-fired:1753713144922=>observerSubmitHandler_received-submit-event:1753713144922=>submit-validation-passed:1753713144929=>observerSubmitHandler_validation-passed-submitting-form:1753713144931=>init-started:1753766883103=>validator-called:1753766883104=>validator-mounted-false:1753766883104=>init-complete:1753766883106=>init-started:1753766885252=>validator-called:1753766885253=>validator-mounted-false:1753766885253=>init-complete:1753766885254=>onsubmit-fired:1753766895907=>observerSubmitHandler_received-submit-event:1753766895907=>submit-validation-passed:1753766895910=>observerSubmitHandler_validation-passed-submitting-form:1753766895913\",\"submitSource\":\"form\",\"submitDate\":\"1753766895913\",\"buildDate\":\"1753766884750\",\"uploadServerUrl\":\"https:\\/\\/upload.jotform.com\\/upload\",\"eventObserver\":\"1\",\"q4_password\":\"somepassword2\",\"q6_school\":\"\",\"q7_schooltext\":\"newschool\",\"q16_headerText\":\"\",\"q17_routeMap\":\"\",\"q11_contactEmail\":\"\",\"q13_instagram\":\"\",\"q14_bluesky\":\"\",\"event_id\":\"1753766885252_5555_jxErYuv\",\"timeToSubmit\":\"10\",\"temp_upload\":{\"q8_headerImage\":[\"Screenshot 2025-07-03 at 08.07.58.png#jotformfs-bc35e2a4de105#019854a7-1a2e-7c71-82f0-8a8880c7334f\"]},\"file_server\":\"jotformfs-bc35e2a4de105#019854a7-1a2e-7c71-82f0-8a8880c7334f\",\"validatedNewRequiredFieldIDs\":\"{\\\"new\\\":1}\",\"path\":\"\\/submit\\/5555\",\"headerImage\":[\"https:\\/\\/www.jotform.com\\/uploads\\/RobG\\/5555\\/6295760960429644172\\/Screenshot%202025-07-03%20at%2008.07.58.png\"]}\r\n--------------------------rDBjFty9dvsCZSUvKYrKRh\r\nContent-Disposition: form-data; name=\"fromTable\"\r\n\r\n\r\n--------------------------rDBjFty9dvsCZSUvKYrKRh\r\nContent-Disposition: form-data; name=\"appID\"\r\n\r\n\r\n--------------------------rDBjFty9dvsCZSUvKYrKRh\r\nContent-Disposition: form-data; name=\"pretty\"\r\n\r\nWhat is the password?:somepassword2, If not listed, add a new school.:newschool, Header Image:Screenshot 2025-07-03 at 08.07.58.png\r\n--------------------------rDBjFty9dvsCZSUvKYrKRh\r\nContent-Disposition: form-data; name=\"unread\"\r\n\r\n\r\n--------------------------rDBjFty9dvsCZSUvKYrKRh\r\nContent-Disposition: form-data; name=\"parent\"\r\n\r\n\r\n--------------------------rDBjFty9dvsCZSUvKYrKRh\r\nContent-Disposition: form-data; name=\"ip\"\r\n\r\n73.96.87.240\r\n--------------------------rDBjFty9dvsCZSUvKYrKRh--\r\n"
      end
      let(:request_headers) do
        {"content-type" => "multipart/form-data; boundary=------------------------rDBjFty9dvsCZSUvKYrKRh"}
      end
      let(:expected_row) do
        include(
          data: hash_including("action" => "", "rawRequest" => be_a(Hash)),
          event_id: "1753766885252_5555_jxErYuv",
          form_id: "5555",
          inserted_at: match_time(:now),
          questions: hash_including("bluesky" => ""),
          submission_id: "6295760960429644172",
        )
      end
    end
  end

  describe "webhook_response" do
    let(:sint) { Webhookdb::Fixtures.service_integration.create(service_name: described_class.descriptor.name) }
    let(:svc) { Webhookdb::Replicator.create(sint) }

    it "returns ok" do
      req = fake_request
      expect(svc.webhook_response(req)).to have_attributes(
        status: 202,
        body: '{"o":"k"}',
        headers: include("content-type" => "application/json"),
      )
    end
  end

  describe "state machine calculation" do
    let(:sint) do
      Webhookdb::Fixtures.service_integration.create(service_name: described_class.descriptor.name, api_url: "")
    end
    let(:svc) { Webhookdb::Replicator.create(sint) }

    describe "calculate_webhook_state_machine" do
      it "provides the webhook URL and database info" do
        sm = svc.calculate_webhook_state_machine
        expect(sm).to have_attributes(
          needs_input: false,
          complete: true,
          output: match(/Jotform submissions to your database/),
        )
      end
    end
  end
  # rubocop:enable Layout/LineLength
end
