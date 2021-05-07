# frozen_string_literal: true

require "support/shared_examples_for_services"
require "rack/test"

RSpec.describe Webhookdb::Services, :db do
  describe "shopify customer v1" do
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

    it_behaves_like "a service implementation that can backfill", "shopify_customer_v1" do
      let(:today) { Time.parse("2020-11-22T18:00:00Z") }

      let(:page1_items) { [{}, {}] }
      let(:page2_items) { [{}] }
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
      around(:each) do |example|
        Timecop.travel(today) do
          example.run
        end
      end
      # rubocop:disable Layout/LineLength
      before(:each) do
        stub_request(:get, "https://fake-url.com/admin/api/2021-04/customers.json").
          with(
            headers: {
              "Accept" => "*/*",
              "Accept-Encoding" => "gzip;q=1.0,deflate;q=0.6,identity;q=0.3",
              "Authorization" => "Basic YmZrZXk6YmZzZWs=",
              "User-Agent" => "Ruby",
            },
          ).
          to_return(status: 200, body: page1_response, headers: {"Content-Type" => "application/json",
                                                                 "Link" => '<https://fake-url.com/admin/api/2021-04/customers.json?limit=2&page_info=abc123>; rel="next", <irrelevant_link>; rel="previous"',},)
        stub_request(:get, "https://fake-url.com/admin/api/2021-04/customers.json?limit=2&page_info=abc123").
          to_return(status: 200, body: page2_response, headers: {"Content-Type" => "application/json",
                                                                 "Link" => '<https://fake-url.com/admin/api/2021-04/customers.json?limit=2&page_info=xyz123>; rel="next", <irrelevant_link>; rel="previous"',},)
        stub_request(:get, "https://fake-url.com/admin/api/2021-04/customers.json?limit=2&page_info=xyz123").
          to_return(status: 200, body: page3_response, headers: {"Content-Type" => "application/json",
                                                                 "Link" => '<irrelevant_link>; rel="previous"',},)
      end
      # rubocop:enable Layout/LineLength
    end
    describe "webhook validation" do
      let(:sint) { Webhookdb::Fixtures.service_integration.create(service_name: "shopify_customer_v1") }
      let(:svc) { Webhookdb::Services.service_instance(sint) }

      it "returns a 401 as per spec if there is no Authorization header" do
        status, headers, body = svc.webhook_response(fake_request)
        expect(status).to eq(401)
        expect(body).to include("missing hmac")
      end

      it "returns a 401 for an invalid Authorization header" do
        sint.update(webhook_secret: "secureuser:pass")
        req = fake_request
        data = req.body
        calculated_hmac = Base64.strict_encode64(OpenSSL::HMAC.digest("sha256", "bad", data))
        req.add_header("HTTP_X_SHOPIFY_HMAC_SHA256", calculated_hmac)
        status, _headers, body = svc.webhook_response(req)
        expect(status).to eq(401)
        expect(body).to include("invalid hmac")
      end

      it "returns a 200 with a valid Authorization header" do
        sint.update(webhook_secret: "user:pass")
        req = fake_request(input: "webhook body")
        data = req.body.read
        calculated_hmac = Base64.strict_encode64(OpenSSL::HMAC.digest("sha256", sint.webhook_secret, data))
        req.add_header("HTTP_X_SHOPIFY_HMAC_SHA256", calculated_hmac)
        status, _headers, _body = svc.webhook_response(req)
        expect(status).to eq(200)
      end
    end
  end
end
