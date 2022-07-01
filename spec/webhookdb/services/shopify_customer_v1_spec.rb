# frozen_string_literal: true

require "support/shared_examples_for_services"

RSpec.describe Webhookdb::Services::ShopifyCustomerV1, :db do
  it_behaves_like "a service implementation", "shopify_customer_v1" do
    let(:body) do
      JSON.parse(<<~J)
        {
          "id": 706405506930370084,
          "email": "bob@biller.com",
          "accepts_marketing": true,
          "created_at": null,
          "updated_at": "2012-08-24T14:01:46-04:00",
          "first_name": "Bob",
          "last_name": "Biller",
          "orders_count": 0,
          "state": "disabled",
          "total_spent": "0.00",
          "last_order_id": null,
          "note": "This customer loves ice cream",
          "verified_email": true,
          "multipass_identifier": null,
          "tax_exempt": false,
          "phone": null,
          "tags": "",
          "last_order_name": null,
          "currency": "USD",
          "addresses": [
          ],
          "accepts_marketing_updated_at": null,
          "marketing_opt_in_level": null,
          "admin_graphql_api_id": "gid:\/\/shopify\/Customer\/706405506930370084"
        }
      J
    end
  end

  it_behaves_like "a service implementation that prevents overwriting new data with old", "shopify_customer_v1" do
    let(:old_body) do
      JSON.parse(<<~J)
        {
          "id": 706405506930370084,
          "email": "bob@biller.com",
          "accepts_marketing": true,
          "created_at": null,
          "updated_at": "2012-08-23T14:01:46-04:00",
          "first_name": "Bob",
          "last_name": "Biller",
          "orders_count": 0,
          "state": "disabled",
          "total_spent": "0.00",
          "last_order_id": null,
          "note": "This customer loves ice cream",
          "verified_email": true,
          "multipass_identifier": null,
          "tax_exempt": false,
          "phone": null,
          "tags": "",
          "last_order_name": null,
          "currency": "USD",
          "addresses": [
          ],
          "accepts_marketing_updated_at": null,
          "marketing_opt_in_level": null,
          "admin_graphql_api_id": "gid:\/\/shopify\/Customer\/706405506930370084"
        }
      J
    end
    let(:new_body) do
      JSON.parse(<<~J)
        {
          "id": 706405506930370084,
          "email": "bob2@biller.com",
          "accepts_marketing": true,
          "created_at": null,
          "updated_at": "2012-08-24T14:01:46-04:00",
          "first_name": "Bob",
          "last_name": "Biller",
          "orders_count": 0,
          "state": "disabled",
          "total_spent": "0.00",
          "last_order_id": null,
          "note": "This customer loves ice cream",
          "verified_email": true,
          "multipass_identifier": null,
          "tax_exempt": false,
          "phone": null,
          "tags": "",
          "last_order_name": null,
          "currency": "USD",
          "addresses": [
          ],
          "accepts_marketing_updated_at": null,
          "marketing_opt_in_level": null,
          "admin_graphql_api_id": "gid:\/\/shopify\/Customer\/706405506930370084"
        }
      J
    end
  end

  it_behaves_like "a service implementation that verifies backfill secrets" do
    let(:correct_creds_sint) do
      Webhookdb::Fixtures.service_integration.create(
        service_name: "shopify_customer_v1",
        api_url: "https://shopify_test.myshopify.com",
        backfill_key: "bfkey",
        backfill_secret: "bfsek",
      )
    end
    let(:incorrect_creds_sint) do
      Webhookdb::Fixtures.service_integration.create(
        service_name: "shopify_customer_v1",
        api_url: "https://shopify_test.myshopify.com",
        backfill_key: "bfkey_wrong",
        backfill_secret: "bfsek",
      )
    end

    let(:success_body) do
      <<~R
        {
          "customers": [],
        }
      R
    end
    def stub_service_request
      return stub_request(:get, "https://shopify_test.myshopify.com/admin/api/2021-04/customers.json").
          with(headers: {"Authorization" => "Basic YmZrZXk6YmZzZWs="}).
          to_return(status: 200, body: success_body, headers: {})
    end

    def stub_service_request_error
      return stub_request(:get, "https://shopify_test.myshopify.com/admin/api/2021-04/customers.json").
          with(headers: {"Authorization" => "Basic YmZrZXlfd3Jvbmc6YmZzZWs="}).
          to_return(status: 401, body: "", headers: {})
    end
  end

  it_behaves_like "a service implementation that can backfill", "shopify_customer_v1" do
    let(:page1_response) do
      <<~R
        {
          "customers": [
            {
              "id": 100000000,
              "email": "bob.norman@hostmail.com",
              "accepts_marketing": false,
              "created_at": "2021-04-01T17:24:20-04:00",
              "updated_at": "2021-04-01T17:24:20-04:00",
              "first_name": "Bob",
              "last_name": "Norman",
              "orders_count": 1,
              "state": "disabled",
              "total_spent": "199.65",
              "last_order_id": 450789469,
              "note": null,
              "verified_email": true,
              "multipass_identifier": null,
              "tax_exempt": false,
              "phone": "+16136120707",
              "tags": "",
              "last_order_name": "#1001",
              "currency": "USD",
              "addresses": [
                {
                  "id": 207119551,
                  "customer_id": 207119551,
                  "first_name": null,
                  "last_name": null,
                  "company": null,
                  "address1": "Chestnut Street 92",
                  "address2": "",
                  "city": "Louisville",
                  "province": "Kentucky",
                  "country": "United States",
                  "zip": "40202",
                  "phone": "555-625-1199",
                  "name": "",
                  "province_code": "KY",
                  "country_code": "US",
                  "country_name": "United States",
                  "default": true
                }
              ],
              "accepts_marketing_updated_at": "2005-06-12T11:57:11-04:00",
              "marketing_opt_in_level": null,
              "tax_exemptions": [],
              "admin_graphql_api_id": "gid://shopify/Customer/207119551",
              "default_address": {
                "id": 207119551,
                "customer_id": 207119551,
                "first_name": null,
                "last_name": null,
                "company": null,
                "address1": "Chestnut Street 92",
                "address2": "",
                "city": "Louisville",
                "province": "Kentucky",
                "country": "United States",
                "zip": "40202",
                "phone": "555-625-1199",
                "name": "",
                "province_code": "KY",
                "country_code": "US",
                "country_name": "United States",
                "default": true
              }
            }
          ]
        }
      R
    end
    let(:page2_response) do
      <<~R
        {
          "customers": [
            {
              "id": 200000000,
              "email": "bob.norman@hostmail.com",
              "accepts_marketing": false,
              "created_at": "2021-04-01T17:24:20-04:00",
              "updated_at": "2021-04-01T17:24:20-04:00",
              "first_name": "Bob",
              "last_name": "Norman",
              "orders_count": 1,
              "state": "disabled",
              "total_spent": "199.65",
              "last_order_id": 450789469,
              "note": null,
              "verified_email": true,
              "multipass_identifier": null,
              "tax_exempt": false,
              "phone": "+16136120707",
              "tags": "",
              "last_order_name": "#1001",
              "currency": "USD",
              "addresses": [
                {
                  "id": 207119551,
                  "customer_id": 207119551,
                  "first_name": null,
                  "last_name": null,
                  "company": null,
                  "address1": "Chestnut Street 92",
                  "address2": "",
                  "city": "Louisville",
                  "province": "Kentucky",
                  "country": "United States",
                  "zip": "40202",
                  "phone": "555-625-1199",
                  "name": "",
                  "province_code": "KY",
                  "country_code": "US",
                  "country_name": "United States",
                  "default": true
                }
              ],
              "accepts_marketing_updated_at": "2005-06-12T11:57:11-04:00",
              "marketing_opt_in_level": null,
              "tax_exemptions": [],
              "admin_graphql_api_id": "gid://shopify/Customer/207119551",
              "default_address": {
                "id": 207119551,
                "customer_id": 207119551,
                "first_name": null,
                "last_name": null,
                "company": null,
                "address1": "Chestnut Street 92",
                "address2": "",
                "city": "Louisville",
                "province": "Kentucky",
                "country": "United States",
                "zip": "40202",
                "phone": "555-625-1199",
                "name": "",
                "province_code": "KY",
                "country_code": "US",
                "country_name": "United States",
                "default": true
              }
            }
          ]
        }
      R
    end
    let(:page3_response) do
      <<~R
        {
          "customers": [
            {
              "id": 300000000,
              "email": "bob.norman@hostmail.com",
              "accepts_marketing": false,
              "created_at": "2021-04-01T17:24:20-04:00",
              "updated_at": "2021-04-01T17:24:20-04:00",
              "first_name": "Bob",
              "last_name": "Norman",
              "orders_count": 1,
              "state": "disabled",
              "total_spent": "199.65",
              "last_order_id": 450789469,
              "note": null,
              "verified_email": true,
              "multipass_identifier": null,
              "tax_exempt": false,
              "phone": "+16136120707",
              "tags": "",
              "last_order_name": "#1001",
              "currency": "USD",
              "addresses": [
                {
                  "id": 207119551,
                  "customer_id": 207119551,
                  "first_name": null,
                  "last_name": null,
                  "company": null,
                  "address1": "Chestnut Street 92",
                  "address2": "",
                  "city": "Louisville",
                  "province": "Kentucky",
                  "country": "United States",
                  "zip": "40202",
                  "phone": "555-625-1199",
                  "name": "",
                  "province_code": "KY",
                  "country_code": "US",
                  "country_name": "United States",
                  "default": true
                }
              ],
              "accepts_marketing_updated_at": "2005-06-12T11:57:11-04:00",
              "marketing_opt_in_level": null,
              "tax_exemptions": [],
              "admin_graphql_api_id": "gid://shopify/Customer/207119551",
              "default_address": {
                "id": 207119551,
                "customer_id": 207119551,
                "first_name": null,
                "last_name": null,
                "company": null,
                "address1": "Chestnut Street 92",
                "address2": "",
                "city": "Louisville",
                "province": "Kentucky",
                "country": "United States",
                "zip": "40202",
                "phone": "555-625-1199",
                "name": "",
                "province_code": "KY",
                "country_code": "US",
                "country_name": "United States",
                "default": true
              }
            }
          ]
        }
      R
    end
    let(:expected_items_count) { 3 }
    # rubocop:disable Layout/LineLength
    def stub_service_requests
      return [
        stub_request(:get, "https://fake-url.com/admin/api/2021-04/customers.json").
            with(headers: {"Authorization" => "Basic YmZrZXk6YmZzZWs="}).
            to_return(
              status: 200,
              body: page1_response,
              headers: {
                "Content-Type" => "application/json",
                "Link" => '<https://fake-url.com/admin/api/2021-04/customers.json?limit=2&page_info=abc123>; rel="next", <irrelevant_link>; rel="previous"',
              },
            ),
        stub_request(:get, "https://fake-url.com/admin/api/2021-04/customers.json?limit=2&page_info=abc123").
            to_return(
              status: 200,
              body: page2_response,
              headers: {
                "Content-Type" => "application/json",
                "Link" => '<https://fake-url.com/admin/api/2021-04/customers.json?limit=2&page_info=xyz123>; rel="next", <irrelevant_link>; rel="previous"',
              },
            ),
        stub_request(:get, "https://fake-url.com/admin/api/2021-04/customers.json?limit=2&page_info=xyz123").
            to_return(
              status: 200,
              body: page3_response,
              headers: {
                "Content-Type" => "application/json",
                "Link" => '<irrelevant_link>; rel="previous"',
              },
            ),
      ]
    end

    # rubocop:enable Layout/LineLength
    def stub_service_request_error
      return stub_request(:get, "https://fake-url.com/admin/api/2021-04/customers.json").
          to_return(status: 500, body: "fuuu")
    end
  end
  describe "webhook validation" do
    let(:sint) { Webhookdb::Fixtures.service_integration.create(service_name: "shopify_customer_v1") }
    let(:svc) { Webhookdb::Services.service_instance(sint) }

    it "returns a 401 as per spec if there is no Authorization header" do
      status, headers, body = svc.webhook_response(fake_request).to_rack
      expect(status).to eq(401)
      expect(body).to include("missing hmac")
    end

    it "returns a 401 for an invalid Authorization header" do
      sint.update(webhook_secret: "secureuser:pass")
      req = fake_request
      data = req.body
      calculated_hmac = Base64.strict_encode64(OpenSSL::HMAC.digest("sha256", "bad", data))
      req.add_header("HTTP_X_SHOPIFY_HMAC_SHA256", calculated_hmac)
      status, _headers, body = svc.webhook_response(req).to_rack
      expect(status).to eq(401)
      expect(body).to include("invalid hmac")
    end

    it "returns a 202 with a valid Authorization header" do
      sint.update(webhook_secret: "user:pass")
      req = fake_request(input: "webhook body")
      data = req.body.read
      calculated_hmac = Base64.strict_encode64(OpenSSL::HMAC.digest("sha256", sint.webhook_secret, data))
      req.add_header("HTTP_X_SHOPIFY_HMAC_SHA256", calculated_hmac)
      status, _headers, _body = svc.webhook_response(req).to_rack
      expect(status).to eq(202)
    end
  end

  describe "state machine calculation" do
    let(:sint) do
      Webhookdb::Fixtures.service_integration.create(service_name: "shopify_customer_v1", backfill_secret: "",
                                                     backfill_key: "", api_url: "",)
    end
    let(:svc) { Webhookdb::Services.service_instance(sint) }

    describe "process_state_change" do
      it "converts a shop name into an api url and updates the object" do
        sint.process_state_change("shop_name", "looney-tunes")
        expect(sint.api_url).to eq("https://looney-tunes.myshopify.com")
      end
    end

    describe "calculate_create_state_machine" do
      it "asks for webhook secret" do
        sm = sint.calculate_create_state_machine
        expect(sm).to have_attributes(
          needs_input: be(true),
          prompt: eq("Paste or type your secret here:"),
          prompt_is_secret: be(true),
          post_to_url: end_with("/service_integrations/#{sint.opaque_id}/transition/webhook_secret"),
          complete: be(false),
          output: match("We've made an endpoint available for Shopify Customer webhooks:"),
        )
      end

      it "confirms reciept of webhook secret, returns org database info" do
        sint.webhook_secret = "whsec_abcasdf"
        sm = sint.calculate_create_state_machine
        expect(sm).to have_attributes(
          needs_input: be(false),
          prompt: "",
          prompt_is_secret: false,
          post_to_url: "",
          complete: be(true),
          output: match("Great! WebhookDB is now listening for Shopify Customer webhooks."),
        )
      end
    end

    describe "calculate_backfill_state_machine" do
      let(:success_body) do
        <<~R
          {
            "customers": [],
          }
        R
      end

      def stub_service_request
        return stub_request(:get, "https://shopify_test.myshopify.com/admin/api/2021-04/customers.json").
            with(headers: {"Authorization" => "Basic a2V5X2doamtsOndoc2VjX2FiY2FzZGY="}).
            to_return(status: 200, body: success_body, headers: {})
      end
      it "asks for backfill key" do
        sm = sint.calculate_backfill_state_machine
        expect(sm).to have_attributes(
          needs_input: true,
          prompt: start_with("Paste or type"),
          prompt_is_secret: true,
          post_to_url: end_with("/service_integrations/#{sint.opaque_id}/transition/backfill_key"),
          complete: false,
          output: match("In order to backfill Shopify Customers, we need an API key and password"),
        )
      end

      it "asks for backfill secret" do
        sint.backfill_key = "key_ghjkl"
        sm = sint.calculate_backfill_state_machine
        expect(sm).to have_attributes(
          needs_input: true,
          prompt: start_with("Paste or type"),
          prompt_is_secret: true,
          post_to_url: end_with("/service_integrations/#{sint.opaque_id}/transition/backfill_secret"),
          complete: false,
          output: "",
        )
      end

      it "asks for store name" do
        sint.backfill_key = "key_ghjkl"
        sint.backfill_secret = "whsec_abcasdf"
        sm = sint.calculate_backfill_state_machine
        expect(sm).to have_attributes(
          needs_input: true,
          prompt: start_with("Paste or type"),
          prompt_is_secret: false,
          post_to_url: end_with("/service_integrations/#{sint.opaque_id}/transition/shop_name"),
          complete: false,
          output: match("Nice! Now we need the name of your shop so that we can construct the api url."),
        )
      end

      it "returns a completed step" do
        sint.backfill_key = "key_ghjkl"
        sint.backfill_secret = "whsec_abcasdf"
        sint.api_url = "https://shopify_test.myshopify.com"
        res = stub_service_request
        sm = sint.calculate_backfill_state_machine
        expect(res).to have_been_made
        expect(sm).to have_attributes(
          needs_input: false,
          prompt: "",
          prompt_is_secret: false,
          post_to_url: "",
          complete: true,
          output: match("Great! We are going to start backfilling your Shopify Customers."),
        )
      end
    end
  end
end
