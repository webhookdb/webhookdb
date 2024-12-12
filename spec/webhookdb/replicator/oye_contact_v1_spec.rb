# frozen_string_literal: true

require "support/shared_examples_for_replicators"

RSpec.describe Webhookdb::Replicator::OyeContactV1, :db do
  let(:org) { Webhookdb::Fixtures.organization.create }
  let(:fac) { Webhookdb::Fixtures.service_integration(organization: org) }
  let(:sint) { fac.create(service_name: "oye_contact_v1") }
  let(:svc) { sint.replicator }

  def contact(**kw)
    return {
      id: 6586,
      number: "+12225558321",
      first_name: "Rhaenyra",
      last_name: " Targaryen",
      created_at: "2023-06-30T20:41:13-04:00",
      updated_at: "2024-04-01T10:43:07-04:00",
      organization_id: 9,
      status: "active",
      state: nil,
      aasm_state: nil,
      state_metadata: nil,
      language: "English",
      eid: "",
    }.merge(kw).as_json
  end

  it_behaves_like "a replicator" do
    let(:sint) { super() }
    let(:body) { contact }
    let(:expected_row) do
      include(
        :pk,
        created_at: match_time("2023-07-01 00:41:13Z"),
        data: hash_including("aasm_state" => nil),
        number: "+12225558321",
        oye_id: "6586",
        status: "active",
        updated_at: match_time("2024-04-01 14:43:07Z"),
      )
    end
  end

  it_behaves_like "a replicator that prevents overwriting new data with old" do
    let(:old_body) { contact }
    let(:new_body) { contact.merge("updated_at" => "2024-04-02 14:43:07Z", "status" => "inactive") }
  end

  it_behaves_like "a replicator that verifies backfill secrets" do
    let(:correct_creds_sint) do
      Webhookdb::Fixtures.service_integration.create(
        service_name: "oye_contact_v1",
        backfill_secret: "goodsecret",
      )
    end
    let(:incorrect_creds_sint) do
      Webhookdb::Fixtures.service_integration.create(
        service_name: "oye_contact_v1",
        backfill_secret: "badsecret",
      )
    end

    def stub_service_request
      return stub_request(:get, "https://app.oyetext.org/api/v1/contacts?search=_do-not-match-anything_").
          to_return(json_response([]))
    end

    def stub_service_request_error
      return stub_request(:get, "https://app.oyetext.org/api/v1/contacts?search=_do-not-match-anything_").
          to_return(status: 401, body: "", headers: {})
    end

    let(:failed_step_matchers) do
      {output: include("It looks like that API Key"), prompt_is_secret: true}
    end

    it "treats no-contact 404s as valid" do
      res = stub_request(:get, "https://app.oyetext.org/api/v1/contacts?search=_do-not-match-anything_").
        to_return(json_response(
                    {message: "There are no contacts who match the search: _do-not-match-anything_"},
                    status: 404,
                  ))
      svc = Webhookdb::Replicator.create(incorrect_creds_sint)
      result = svc.verify_backfill_credentials
      expect(res).to have_been_made
      expect(result).to have_attributes(verified: true)
    end

    it "treats other 404s as unhandled" do
      res = stub_request(:get, "https://app.oyetext.org/api/v1/contacts?search=_do-not-match-anything_").
        to_return(status: 404, body: "route does not exist", headers: {})
      svc = Webhookdb::Replicator.create(incorrect_creds_sint)
      expect do
        svc.verify_backfill_credentials
      end.to raise_error(Webhookdb::Http::Error)
      expect(res).to have_been_made
    end

    it "treats other errors as unhandled" do
      res = stub_request(:get, "https://app.oyetext.org/api/v1/contacts?search=_do-not-match-anything_").
        to_return(status: 403, body: "", headers: {})
      svc = Webhookdb::Replicator.create(incorrect_creds_sint)
      expect do
        svc.verify_backfill_credentials
      end.to raise_error(Webhookdb::Http::Error)
      expect(res).to have_been_made
    end
  end

  it_behaves_like "a replicator that can backfill" do
    let(:page1_response) do
      [contact, contact(id: 7000)]
    end
    let(:expected_items_count) { 2 }

    def stub_service_requests
      return [
        stub_request(:get, "https://app.oyetext.org/api/v1/contacts").
            to_return(json_response(page1_response)),
      ]
    end

    def stub_empty_requests
      return [
        stub_request(:get, "https://app.oyetext.org/api/v1/contacts").
            to_return(json_response([])),
      ]
    end

    def stub_service_request_error
      return stub_request(:get, "https://app.oyetext.org/api/v1/contacts").
          to_return(status: 403, body: "ahhh")
    end
  end

  describe "state machine calculation" do
    before(:each) do
      sint.update(api_url: "")
    end

    describe "calculate_backfill_state_machine" do
      it "prompts for the backfill secret" do
        sm = sint.replicator.calculate_backfill_state_machine
        expect(sm).to have_attributes(
          needs_input: true,
          complete: false,
          output: include("we need your Oye API key"),
          prompt: include("your API Key here"),
        )
      end

      it "completes if backfill secret" do
        req = stub_request(:get, "https://app.oyetext.org/api/v1/contacts?search=_do-not-match-anything_").
          to_return(json_response([]))
        sint.backfill_secret = "fooo"
        sm = sint.replicator.calculate_backfill_state_machine
        expect(sm).to have_attributes(
          needs_input: false,
          complete: true,
          output: include("replicating your Oye contacts"),
        )
        expect(req).to have_been_made
      end
    end
  end

  describe "webhook_response" do
    it "is ok" do
      expect(svc.webhook_response(fake_request)).to have_attributes(status: 202)
    end
  end
end
