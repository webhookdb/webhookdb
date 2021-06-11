# frozen_string_literal: true

require "support/shared_examples_for_services"

RSpec.describe Webhookdb::Services, :db do
  describe "shopify order v1" do
    it_behaves_like "a service implementation", "shopify_order_v1" do
      let(:body) do
        JSON.parse(<<~J)
                                {
            "app_id": 1966818,
            "billing_address": {
              "address1": "2259 Park Ct",
              "address2": "Apartment 5",
              "city": "Drayton Valley",
              "company": null,
              "country": "Canada",
              "country_code": "CA",
              "first_name": "Christopher",
              "last_name": "Gorski",
              "latitude": "45.41634",
              "longitude": "-75.6868",
              "name": "Christopher Gorski",
              "phone": "(555)555-5555",
              "province": "Alberta",
              "province_code": "AB",
              "zip": "T0E 0M0"
            },
            "browser_ip": "216.191.105.146",
            "buyer_accepts_marketing": false,
            "cancel_reason": "customer",
            "cancelled_at": null,
            "cart_token": "68778783ad298f1c80c3bafcddeea",
            "checkout_token": "bd5a8aa1ecd019dd3520ff791ee3a24c",
            "client_details": {
              "accept_language": "en-US,en;q=0.9",
              "browser_height": 1320,
              "browser_ip": "216.191.105.146",
              "browser_width": 1280,
              "session_hash": "9ad4d1f4e6a8977b9dd98eed1e477643",
              "user_agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_13_1) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/62.0.3202.94 Safari/537.36"
            },
            "closed_at": "2008-01-10T11:00:00-05:00",
            "created_at": "2008-01-10T11:00:00-05:00",
            "currency": "USD",
            "current_subtotal_price": "10.00",
            "current_subtotal_price_set": {
              "presentment_money": {
                "amount": "20.00",
                "currency_code": "EUR"
              },
              "shop_money": {
                "amount": "30.00",
                "currency_code": "CAD"
              }
            },
            "current_total_discounts": "10.00",
            "current_total_discounts_set": {
              "presentment_money": {
                "amount": "5.00",
                "currency_code": "EUR"
              },
              "shop_money": {
                "amount": "10.00",
                "currency_code": "CAD"
              }
            },
            "current_total_duties_set": {
              "presentment_money": {
                "amount": "105.31",
                "currency_code": "EUR"
              },
              "shop_money": {
                "amount": "164.86",
                "currency_code": "CAD"
              }
            },
            "current_total_price": "10.00",
            "current_total_price_set": {
              "presentment_money": {
                "amount": "20.00",
                "currency_code": "EUR"
              },
              "shop_money": {
                "amount": "30.00",
                "currency_code": "CAD"
              }
            },
            "current_total_tax": "10.00",
            "current_total_tax_set": {
              "presentment_money": {
                "amount": "20.00",
                "currency_code": "EUR"
              },
              "shop_money": {
                "amount": "30.00",
                "currency_code": "CAD"
              }
            },
            "customer": {
              "accepts_marketing": false,
              "addresses": {},
              "admin_graphql_api_id": "gid://shopify/Customer/207119551",
              "created_at": "2012-03-13T16:09:55-04:00",
              "currency": "USD",
              "default_address": {},
              "email": "bob.norman@hostmail.com",
              "first_name": "Bob",
              "id": 207119551,
              "last_name": "Norman",
              "last_order_id": 450789469,
              "last_order_name": "#1001",
              "multipass_identifier": null,
              "note": null,
              "orders_count": "1",
              "phone": "+13125551212",
              "state": "disabled",
              "tags": "loyal",
              "tax_exempt": false,
              "tax_exemptions": {},
              "total_spent": "0.00",
              "updated_at": "2012-03-13T16:09:55-04:00",
              "verified_email": true
            },
            "customer_locale": "en-CA",
            "discount_applications": [
              {
                "allocation_method": "across",
                "description": "customer deserved it",
                "target_selection": "explicit",
                "target_type": "line_item",
                "title": "custom discount",
                "type": "manual",
                "value": "2.0",
                "value_type": "fixed_amount"
              },
              {
                "allocation_method": "across",
                "description": "my scripted discount",
                "target_selection": "explicit",
                "target_type": "shipping_line",
                "type": "script",
                "value": "5.0",
                "value_type": "fixed_amount"
              },
              {
                "allocation_method": "across",
                "code": "SUMMERSALE",
                "target_selection": "all",
                "target_type": "line_item",
                "type": "discount_code",
                "value": "10.0",
                "value_type": "fixed_amount"
              }
            ],
            "discount_codes": [
              {
                "amount": "30.00",
                "code": "SPRING30",
                "type": "fixed_amount"
              }
            ],
            "email": "bob.norman@hostmail.com",
            "financial_status": "authorized",
            "fulfillment_status": "partial",
            "fulfillments": [
              {
                "created_at": "2012-03-13T16:09:54-04:00",
                "id": 255858046,
                "order_id": 450789469,
                "status": "failure",
                "tracking_company": "USPS",
                "tracking_number": "1Z2345",
                "updated_at": "2012-05-01T14:22:25-04:00"
              }
            ],
            "gateway": "shopify_payments",
            "id": 450789469,
            "landing_site": "http://www.example.com?source=abc",
            "line_items": [
              {
                "discount_allocations": [
                  {
                    "amount": "5.00",
                    "amount_set": {
                      "presentment_money": {
                        "amount": "3.96",
                        "currency_code": "EUR"
                      },
                      "shop_money": {
                        "amount": "5.00",
                        "currency_code": "USD"
                      }
                    },
                    "discount_application_index": 2
                  }
                ],
                "duties": [
                  {
                    "admin_graphql_api_id": "gid://shopify/Duty/2",
                    "country_code_of_origin": "CA",
                    "harmonized_system_code": "520300",
                    "id": "2",
                    "presentment_money": {
                      "amount": "105.31",
                      "currency_code": "EUR"
                    },
                    "shop_money": {
                      "amount": "164.86",
                      "currency_code": "CAD"
                    },
                    "tax_lines": [
                      {
                        "price": "16.486",
                        "price_set": {
                          "presentment_money": {
                            "amount": "10.531",
                            "currency_code": "EUR"
                          },
                          "shop_money": {
                            "amount": "16.486",
                            "currency_code": "CAD"
                          }
                        },
                        "rate": 0.1,
                        "title": "VAT"
                      }
                    ]
                  }
                ],
                "fulfillable_quantity": 1,
                "fulfillment_service": "amazon",
                "fulfillment_status": "fulfilled",
                "gift_card": false,
                "grams": 500,
                "id": 669751112,
                "name": "IPod Nano - Pink",
                "origin_location": {
                  "address1": "700 West Georgia Street",
                  "address2": "1500",
                  "city": "Toronto",
                  "country_code": "CA",
                  "id": 1390592786454,
                  "name": "Apple",
                  "province_code": "ON",
                  "zip": "V7Y 1G5"
                },
                "price": "199.99",
                "price_set": {
                  "presentment_money": {
                    "amount": "173.30",
                    "currency_code": "EUR"
                  },
                  "shop_money": {
                    "amount": "199.99",
                    "currency_code": "USD"
                  }
                },
                "product_id": 7513594,
                "properties": [
                  {
                    "name": "custom engraving",
                    "value": "Happy Birthday Mom!"
                  }
                ],
                "quantity": 1,
                "requires_shipping": true,
                "sku": "IPOD-342-N",
                "tax_lines": [
                  {
                    "price": "25.81",
                    "price_set": {
                      "presentment_money": {
                        "amount": "20.15",
                        "currency_code": "EUR"
                      },
                      "shop_money": {
                        "amount": "25.81",
                        "currency_code": "USD"
                      }
                    },
                    "rate": 0.13,
                    "title": "HST"
                  }
                ],
                "taxable": true,
                "title": "IPod Nano",
                "total_discount": "5.00",
                "total_discount_set": {
                  "presentment_money": {
                    "amount": "4.30",
                    "currency_code": "EUR"
                  },
                  "shop_money": {
                    "amount": "5.00",
                    "currency_code": "USD"
                  }
                },
                "variant_id": 4264112,
                "variant_title": "Pink",
                "vendor": "Apple"
              }
            ],
            "location_id": 49202758,
            "name": "#1001",
            "note": "Customer changed their mind.",
            "note_attributes": [
              {
                "name": "custom name",
                "value": "custom value"
              }
            ],
            "number": 1,
            "order_number": 1001,
            "order_status_url": "https://checkout.shopify.com/112233/checkouts/4207896aad57dfb159/thank_you_token?key=753621327b9e8a64789651bf221dfe35",
            "original_total_duties_set": {
              "presentment_money": {
                "amount": "105.31",
                "currency_code": "EUR"
              },
              "shop_money": {
                "amount": "164.86",
                "currency_code": "CAD"
              }
            },
            "payment_details": {
              "avs_result_code": "Y",
              "credit_card_bin": "453600",
              "credit_card_company": "Visa",
              "credit_card_number": "•••• •••• •••• 4242",
              "cvv_result_code": "M"
            },
            "payment_gateway_names": [
              "authorize_net",
              "Cash on Delivery (COD)"
            ],
            "phone": "+557734881234",
            "presentment_currency": "CAD",
            "processed_at": "2008-01-10T11:00:00-05:00",
            "processing_method": "direct",
            "referring_site": "http://www.anexample.com",
            "refunds": [
              {
                "created_at": "2018-03-06T09:35:37-05:00",
                "id": 18423447608,
                "note": null,
                "order_adjustments": [],
                "order_id": 394481795128,
                "processed_at": "2018-03-06T09:35:37-05:00",
                "refund_line_items": [],
                "transactions": [],
                "user_id": null
              }
            ],
            "shipping_address": {
              "address1": "123 Amoebobacterieae St",
              "address2": "",
              "city": "Ottawa",
              "company": null,
              "country": "Canada",
              "country_code": "CA",
              "first_name": "Bob",
              "last_name": "Bobsen",
              "latitude": "45.41634",
              "longitude": "-75.6868",
              "name": "Bob Bobsen",
              "phone": "555-625-1199",
              "province": "Ontario",
              "province_code": "ON",
              "zip": "K2P0V6"
            },
            "shipping_lines": [
              {
                "carrier_identifier": "third_party_carrier_identifier",
                "code": "INT.TP",
                "discounted_price": "4.00",
                "discounted_price_set": {
                  "presentment_money": {
                    "amount": "3.17",
                    "currency_code": "EUR"
                  },
                  "shop_money": {
                    "amount": "4.00",
                    "currency_code": "USD"
                  }
                },
                "price": "4.00",
                "price_set": {
                  "presentment_money": {
                    "amount": "3.17",
                    "currency_code": "EUR"
                  },
                  "shop_money": {
                    "amount": "4.00",
                    "currency_code": "USD"
                  }
                },
                "requested_fulfillment_service_id": "third_party_fulfillment_service_id",
                "source": "canada_post",
                "tax_lines": [],
                "title": "Small Packet International Air"
              }
            ],
            "source_name": "web",
            "subtotal_price": 398.0,
            "subtotal_price_set": {
              "presentment_money": {
                "amount": "90.95",
                "currency_code": "EUR"
              },
              "shop_money": {
                "amount": "141.99",
                "currency_code": "CAD"
              }
            },
            "tags": "imported",
            "tax_lines": [
              {
                "price": 11.94,
                "rate": 0.06,
                "title": "State Tax"
              }
            ],
            "taxes_included": false,
            "test": true,
            "token": "b1946ac92492d2347c6235b4d2611184",
            "total_discounts": "0.00",
            "total_discounts_set": {
              "presentment_money": {
                "amount": "0.00",
                "currency_code": "EUR"
              },
              "shop_money": {
                "amount": "0.00",
                "currency_code": "CAD"
              }
            },
            "total_line_items_price": "398.00",
            "total_line_items_price_set": {
              "presentment_money": {
                "amount": "90.95",
                "currency_code": "EUR"
              },
              "shop_money": {
                "amount": "141.99",
                "currency_code": "CAD"
              }
            },
            "total_outstanding": "5.00",
            "total_price": "409.94",
            "total_price_set": {
              "presentment_money": {
                "amount": "105.31",
                "currency_code": "EUR"
              },
              "shop_money": {
                "amount": "164.86",
                "currency_code": "CAD"
              }
            },
            "total_shipping_price_set": {
              "presentment_money": {
                "amount": "0.00",
                "currency_code": "USD"
              },
              "shop_money": {
                "amount": "30.00",
                "currency_code": "USD"
              }
            },
            "total_tax": "11.94",
            "total_tax_set": {
              "presentment_money": {
                "amount": "11.82",
                "currency_code": "EUR"
              },
              "shop_money": {
                "amount": "18.87",
                "currency_code": "CAD"
              }
            },
            "total_tip_received": "4.87",
            "total_weight": 300,
            "updated_at": "2012-08-24T14:02:15-04:00",
            "user_id": 31522279
          }
        J
      end
    end

    it_behaves_like "a service implementation that prevents overwriting new data with old", "shopify_order_v1" do
      let(:old_body) do
        JSON.parse(<<~J)
                    {
            "app_id": 1966818,
            "billing_address": {
              "address1": "2259 Park Ct",
              "address2": "Apartment 5",
              "city": "Drayton Valley",
              "company": null,
              "country": "Canada",
              "country_code": "CA",
              "first_name": "Christopher",
              "last_name": "Gorski",
              "latitude": "45.41634",
              "longitude": "-75.6868",
              "name": "Christopher Gorski",
              "phone": "(555)555-5555",
              "province": "Alberta",
              "province_code": "AB",
              "zip": "T0E 0M0"
            },
            "browser_ip": "216.191.105.146",
            "buyer_accepts_marketing": false,
            "cancel_reason": "customer",
            "cancelled_at": null,
            "cart_token": "68778783ad298f1c80c3bafcddeea",
            "checkout_token": "bd5a8aa1ecd019dd3520ff791ee3a24c",
            "client_details": {
              "accept_language": "en-US,en;q=0.9",
              "browser_height": 1320,
              "browser_ip": "216.191.105.146",
              "browser_width": 1280,
              "session_hash": "9ad4d1f4e6a8977b9dd98eed1e477643",
              "user_agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_13_1) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/62.0.3202.94 Safari/537.36"
            },
            "closed_at": "2008-01-10T11:00:00-05:00",
            "created_at": "2008-01-10T11:00:00-05:00",
            "currency": "USD",
            "current_subtotal_price": "10.00",
            "current_subtotal_price_set": {
              "presentment_money": {
                "amount": "20.00",
                "currency_code": "EUR"
              },
              "shop_money": {
                "amount": "30.00",
                "currency_code": "CAD"
              }
            },
            "current_total_discounts": "10.00",
            "current_total_discounts_set": {
              "presentment_money": {
                "amount": "5.00",
                "currency_code": "EUR"
              },
              "shop_money": {
                "amount": "10.00",
                "currency_code": "CAD"
              }
            },
            "current_total_duties_set": {
              "presentment_money": {
                "amount": "105.31",
                "currency_code": "EUR"
              },
              "shop_money": {
                "amount": "164.86",
                "currency_code": "CAD"
              }
            },
            "current_total_price": "10.00",
            "current_total_price_set": {
              "presentment_money": {
                "amount": "20.00",
                "currency_code": "EUR"
              },
              "shop_money": {
                "amount": "30.00",
                "currency_code": "CAD"
              }
            },
            "current_total_tax": "10.00",
            "current_total_tax_set": {
              "presentment_money": {
                "amount": "20.00",
                "currency_code": "EUR"
              },
              "shop_money": {
                "amount": "30.00",
                "currency_code": "CAD"
              }
            },
            "customer": {
              "accepts_marketing": false,
              "addresses": {},
              "admin_graphql_api_id": "gid://shopify/Customer/207119551",
              "created_at": "2012-03-13T16:09:55-04:00",
              "currency": "USD",
              "default_address": {},
              "email": "bob.norman@hostmail.com",
              "first_name": "Bob",
              "id": 207119551,
              "last_name": "Norman",
              "last_order_id": 450789469,
              "last_order_name": "#1001",
              "multipass_identifier": null,
              "note": null,
              "orders_count": "1",
              "phone": "+13125551212",
              "state": "disabled",
              "tags": "loyal",
              "tax_exempt": false,
              "tax_exemptions": {},
              "total_spent": "0.00",
              "updated_at": "2012-03-13T16:09:55-04:00",
              "verified_email": true
            },
            "customer_locale": "en-CA",
            "discount_applications": [
              {
                "allocation_method": "across",
                "description": "customer deserved it",
                "target_selection": "explicit",
                "target_type": "line_item",
                "title": "custom discount",
                "type": "manual",
                "value": "2.0",
                "value_type": "fixed_amount"
              },
              {
                "allocation_method": "across",
                "description": "my scripted discount",
                "target_selection": "explicit",
                "target_type": "shipping_line",
                "type": "script",
                "value": "5.0",
                "value_type": "fixed_amount"
              },
              {
                "allocation_method": "across",
                "code": "SUMMERSALE",
                "target_selection": "all",
                "target_type": "line_item",
                "type": "discount_code",
                "value": "10.0",
                "value_type": "fixed_amount"
              }
            ],
            "discount_codes": [
              {
                "amount": "30.00",
                "code": "SPRING30",
                "type": "fixed_amount"
              }
            ],
            "email": "bob.norman@hostmail.com",
            "financial_status": "authorized",
            "fulfillment_status": "partial",
            "fulfillments": [
              {
                "created_at": "2012-03-13T16:09:54-04:00",
                "id": 255858046,
                "order_id": 450789469,
                "status": "failure",
                "tracking_company": "USPS",
                "tracking_number": "1Z2345",
                "updated_at": "2012-05-01T14:22:25-04:00"
              }
            ],
            "gateway": "shopify_payments",
            "id": 450789469,
            "landing_site": "http://www.example.com?source=abc",
            "line_items": [
              {
                "discount_allocations": [
                  {
                    "amount": "5.00",
                    "amount_set": {
                      "presentment_money": {
                        "amount": "3.96",
                        "currency_code": "EUR"
                      },
                      "shop_money": {
                        "amount": "5.00",
                        "currency_code": "USD"
                      }
                    },
                    "discount_application_index": 2
                  }
                ],
                "duties": [
                  {
                    "admin_graphql_api_id": "gid://shopify/Duty/2",
                    "country_code_of_origin": "CA",
                    "harmonized_system_code": "520300",
                    "id": "2",
                    "presentment_money": {
                      "amount": "105.31",
                      "currency_code": "EUR"
                    },
                    "shop_money": {
                      "amount": "164.86",
                      "currency_code": "CAD"
                    },
                    "tax_lines": [
                      {
                        "price": "16.486",
                        "price_set": {
                          "presentment_money": {
                            "amount": "10.531",
                            "currency_code": "EUR"
                          },
                          "shop_money": {
                            "amount": "16.486",
                            "currency_code": "CAD"
                          }
                        },
                        "rate": 0.1,
                        "title": "VAT"
                      }
                    ]
                  }
                ],
                "fulfillable_quantity": 1,
                "fulfillment_service": "amazon",
                "fulfillment_status": "fulfilled",
                "gift_card": false,
                "grams": 500,
                "id": 669751112,
                "name": "IPod Nano - Pink",
                "origin_location": {
                  "address1": "700 West Georgia Street",
                  "address2": "1500",
                  "city": "Toronto",
                  "country_code": "CA",
                  "id": 1390592786454,
                  "name": "Apple",
                  "province_code": "ON",
                  "zip": "V7Y 1G5"
                },
                "price": "199.99",
                "price_set": {
                  "presentment_money": {
                    "amount": "173.30",
                    "currency_code": "EUR"
                  },
                  "shop_money": {
                    "amount": "199.99",
                    "currency_code": "USD"
                  }
                },
                "product_id": 7513594,
                "properties": [
                  {
                    "name": "custom engraving",
                    "value": "Happy Birthday Mom!"
                  }
                ],
                "quantity": 1,
                "requires_shipping": true,
                "sku": "IPOD-342-N",
                "tax_lines": [
                  {
                    "price": "25.81",
                    "price_set": {
                      "presentment_money": {
                        "amount": "20.15",
                        "currency_code": "EUR"
                      },
                      "shop_money": {
                        "amount": "25.81",
                        "currency_code": "USD"
                      }
                    },
                    "rate": 0.13,
                    "title": "HST"
                  }
                ],
                "taxable": true,
                "title": "IPod Nano",
                "total_discount": "5.00",
                "total_discount_set": {
                  "presentment_money": {
                    "amount": "4.30",
                    "currency_code": "EUR"
                  },
                  "shop_money": {
                    "amount": "5.00",
                    "currency_code": "USD"
                  }
                },
                "variant_id": 4264112,
                "variant_title": "Pink",
                "vendor": "Apple"
              }
            ],
            "location_id": 49202758,
            "name": "#1001",
            "note": "Customer changed their mind.",
            "note_attributes": [
              {
                "name": "custom name",
                "value": "custom value"
              }
            ],
            "number": 1,
            "order_number": 1001,
            "order_status_url": "https://checkout.shopify.com/112233/checkouts/4207896aad57dfb159/thank_you_token?key=753621327b9e8a64789651bf221dfe35",
            "original_total_duties_set": {
              "presentment_money": {
                "amount": "105.31",
                "currency_code": "EUR"
              },
              "shop_money": {
                "amount": "164.86",
                "currency_code": "CAD"
              }
            },
            "payment_details": {
              "avs_result_code": "Y",
              "credit_card_bin": "453600",
              "credit_card_company": "Visa",
              "credit_card_number": "•••• •••• •••• 4242",
              "cvv_result_code": "M"
            },
            "payment_gateway_names": [
              "authorize_net",
              "Cash on Delivery (COD)"
            ],
            "phone": "+557734881234",
            "presentment_currency": "CAD",
            "processed_at": "2008-01-10T11:00:00-05:00",
            "processing_method": "direct",
            "referring_site": "http://www.anexample.com",
            "refunds": [
              {
                "created_at": "2018-03-06T09:35:37-05:00",
                "id": 18423447608,
                "note": null,
                "order_adjustments": [],
                "order_id": 394481795128,
                "processed_at": "2018-03-06T09:35:37-05:00",
                "refund_line_items": [],
                "transactions": [],
                "user_id": null
              }
            ],
            "shipping_address": {
              "address1": "123 Amoebobacterieae St",
              "address2": "",
              "city": "Ottawa",
              "company": null,
              "country": "Canada",
              "country_code": "CA",
              "first_name": "Bob",
              "last_name": "Bobsen",
              "latitude": "45.41634",
              "longitude": "-75.6868",
              "name": "Bob Bobsen",
              "phone": "555-625-1199",
              "province": "Ontario",
              "province_code": "ON",
              "zip": "K2P0V6"
            },
            "shipping_lines": [
              {
                "carrier_identifier": "third_party_carrier_identifier",
                "code": "INT.TP",
                "discounted_price": "4.00",
                "discounted_price_set": {
                  "presentment_money": {
                    "amount": "3.17",
                    "currency_code": "EUR"
                  },
                  "shop_money": {
                    "amount": "4.00",
                    "currency_code": "USD"
                  }
                },
                "price": "4.00",
                "price_set": {
                  "presentment_money": {
                    "amount": "3.17",
                    "currency_code": "EUR"
                  },
                  "shop_money": {
                    "amount": "4.00",
                    "currency_code": "USD"
                  }
                },
                "requested_fulfillment_service_id": "third_party_fulfillment_service_id",
                "source": "canada_post",
                "tax_lines": [],
                "title": "Small Packet International Air"
              }
            ],
            "source_name": "web",
            "subtotal_price": 398.0,
            "subtotal_price_set": {
              "presentment_money": {
                "amount": "90.95",
                "currency_code": "EUR"
              },
              "shop_money": {
                "amount": "141.99",
                "currency_code": "CAD"
              }
            },
            "tags": "imported",
            "tax_lines": [
              {
                "price": 11.94,
                "rate": 0.06,
                "title": "State Tax"
              }
            ],
            "taxes_included": false,
            "test": true,
            "token": "b1946ac92492d2347c6235b4d2611184",
            "total_discounts": "0.00",
            "total_discounts_set": {
              "presentment_money": {
                "amount": "0.00",
                "currency_code": "EUR"
              },
              "shop_money": {
                "amount": "0.00",
                "currency_code": "CAD"
              }
            },
            "total_line_items_price": "398.00",
            "total_line_items_price_set": {
              "presentment_money": {
                "amount": "90.95",
                "currency_code": "EUR"
              },
              "shop_money": {
                "amount": "141.99",
                "currency_code": "CAD"
              }
            },
            "total_outstanding": "5.00",
            "total_price": "409.94",
            "total_price_set": {
              "presentment_money": {
                "amount": "105.31",
                "currency_code": "EUR"
              },
              "shop_money": {
                "amount": "164.86",
                "currency_code": "CAD"
              }
            },
            "total_shipping_price_set": {
              "presentment_money": {
                "amount": "0.00",
                "currency_code": "USD"
              },
              "shop_money": {
                "amount": "30.00",
                "currency_code": "USD"
              }
            },
            "total_tax": "11.94",
            "total_tax_set": {
              "presentment_money": {
                "amount": "11.82",
                "currency_code": "EUR"
              },
              "shop_money": {
                "amount": "18.87",
                "currency_code": "CAD"
              }
            },
            "total_tip_received": "4.87",
            "total_weight": 300,
            "updated_at": "2012-08-24T14:02:15-04:00",
            "user_id": 31522279
          }
        J
      end
      let(:new_body) do
        JSON.parse(<<~J)
                    {
            "app_id": 1966818,
            "billing_address": {
              "address1": "2259 Park Ct",
              "address2": "Apartment 5",
              "city": "Drayton Valley",
              "company": null,
              "country": "Canada",
              "country_code": "CA",
              "first_name": "Christopher",
              "last_name": "Gorski",
              "latitude": "45.41634",
              "longitude": "-75.6868",
              "name": "Christopher Gorski",
              "phone": "(555)555-5555",
              "province": "Alberta",
              "province_code": "AB",
              "zip": "T0E 0M0"
            },
            "browser_ip": "216.191.105.146",
            "buyer_accepts_marketing": false,
            "cancel_reason": "customer",
            "cancelled_at": null,
            "cart_token": "68778783ad298f1c80c3bafcddeea",
            "checkout_token": "bd5a8aa1ecd019dd3520ff791ee3a24c",
            "client_details": {
              "accept_language": "en-US,en;q=0.9",
              "browser_height": 1320,
              "browser_ip": "216.191.105.146",
              "browser_width": 1280,
              "session_hash": "9ad4d1f4e6a8977b9dd98eed1e477643",
              "user_agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_13_1) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/62.0.3202.94 Safari/537.36"
            },
            "closed_at": "2008-01-10T11:00:00-05:00",
            "created_at": "2008-01-10T11:00:00-05:00",
            "currency": "USD",
            "current_subtotal_price": "10.00",
            "current_subtotal_price_set": {
              "presentment_money": {
                "amount": "20.00",
                "currency_code": "EUR"
              },
              "shop_money": {
                "amount": "30.00",
                "currency_code": "CAD"
              }
            },
            "current_total_discounts": "10.00",
            "current_total_discounts_set": {
              "presentment_money": {
                "amount": "5.00",
                "currency_code": "EUR"
              },
              "shop_money": {
                "amount": "10.00",
                "currency_code": "CAD"
              }
            },
            "current_total_duties_set": {
              "presentment_money": {
                "amount": "105.31",
                "currency_code": "EUR"
              },
              "shop_money": {
                "amount": "164.86",
                "currency_code": "CAD"
              }
            },
            "current_total_price": "10.00",
            "current_total_price_set": {
              "presentment_money": {
                "amount": "20.00",
                "currency_code": "EUR"
              },
              "shop_money": {
                "amount": "30.00",
                "currency_code": "CAD"
              }
            },
            "current_total_tax": "10.00",
            "current_total_tax_set": {
              "presentment_money": {
                "amount": "20.00",
                "currency_code": "EUR"
              },
              "shop_money": {
                "amount": "30.00",
                "currency_code": "CAD"
              }
            },
            "customer": {
              "accepts_marketing": false,
              "addresses": {},
              "admin_graphql_api_id": "gid://shopify/Customer/207119551",
              "created_at": "2012-03-13T16:09:55-04:00",
              "currency": "USD",
              "default_address": {},
              "email": "bob.norman@hostmail.com",
              "first_name": "Bob",
              "id": 207119551,
              "last_name": "Norman",
              "last_order_id": 450789469,
              "last_order_name": "#1001",
              "multipass_identifier": null,
              "note": null,
              "orders_count": "1",
              "phone": "+13125551212",
              "state": "disabled",
              "tags": "loyal",
              "tax_exempt": false,
              "tax_exemptions": {},
              "total_spent": "0.00",
              "updated_at": "2012-03-13T16:09:55-04:00",
              "verified_email": true
            },
            "customer_locale": "en-CA",
            "discount_applications": [
              {
                "allocation_method": "across",
                "description": "customer deserved it",
                "target_selection": "explicit",
                "target_type": "line_item",
                "title": "custom discount",
                "type": "manual",
                "value": "2.0",
                "value_type": "fixed_amount"
              },
              {
                "allocation_method": "across",
                "description": "my scripted discount",
                "target_selection": "explicit",
                "target_type": "shipping_line",
                "type": "script",
                "value": "5.0",
                "value_type": "fixed_amount"
              },
              {
                "allocation_method": "across",
                "code": "SUMMERSALE",
                "target_selection": "all",
                "target_type": "line_item",
                "type": "discount_code",
                "value": "10.0",
                "value_type": "fixed_amount"
              }
            ],
            "discount_codes": [
              {
                "amount": "30.00",
                "code": "SPRING30",
                "type": "fixed_amount"
              }
            ],
            "email": "bob.norman@hostmail.com",
            "financial_status": "authorized",
            "fulfillment_status": "partial",
            "fulfillments": [
              {
                "created_at": "2012-03-13T16:09:54-04:00",
                "id": 255858046,
                "order_id": 450789469,
                "status": "failure",
                "tracking_company": "USPS",
                "tracking_number": "1Z2345",
                "updated_at": "2012-05-01T14:22:25-04:00"
              }
            ],
            "gateway": "shopify_payments",
            "id": 450789469,
            "landing_site": "http://www.example.com?source=abc",
            "line_items": [
              {
                "discount_allocations": [
                  {
                    "amount": "5.00",
                    "amount_set": {
                      "presentment_money": {
                        "amount": "3.96",
                        "currency_code": "EUR"
                      },
                      "shop_money": {
                        "amount": "5.00",
                        "currency_code": "USD"
                      }
                    },
                    "discount_application_index": 2
                  }
                ],
                "duties": [
                  {
                    "admin_graphql_api_id": "gid://shopify/Duty/2",
                    "country_code_of_origin": "CA",
                    "harmonized_system_code": "520300",
                    "id": "2",
                    "presentment_money": {
                      "amount": "105.31",
                      "currency_code": "EUR"
                    },
                    "shop_money": {
                      "amount": "164.86",
                      "currency_code": "CAD"
                    },
                    "tax_lines": [
                      {
                        "price": "16.486",
                        "price_set": {
                          "presentment_money": {
                            "amount": "10.531",
                            "currency_code": "EUR"
                          },
                          "shop_money": {
                            "amount": "16.486",
                            "currency_code": "CAD"
                          }
                        },
                        "rate": 0.1,
                        "title": "VAT"
                      }
                    ]
                  }
                ],
                "fulfillable_quantity": 1,
                "fulfillment_service": "amazon",
                "fulfillment_status": "fulfilled",
                "gift_card": false,
                "grams": 500,
                "id": 669751112,
                "name": "IPod Nano - Pink",
                "origin_location": {
                  "address1": "700 West Georgia Street",
                  "address2": "1500",
                  "city": "Toronto",
                  "country_code": "CA",
                  "id": 1390592786454,
                  "name": "Apple",
                  "province_code": "ON",
                  "zip": "V7Y 1G5"
                },
                "price": "199.99",
                "price_set": {
                  "presentment_money": {
                    "amount": "173.30",
                    "currency_code": "EUR"
                  },
                  "shop_money": {
                    "amount": "199.99",
                    "currency_code": "USD"
                  }
                },
                "product_id": 7513594,
                "properties": [
                  {
                    "name": "custom engraving",
                    "value": "Happy Birthday Mom!"
                  }
                ],
                "quantity": 1,
                "requires_shipping": true,
                "sku": "IPOD-342-N",
                "tax_lines": [
                  {
                    "price": "25.81",
                    "price_set": {
                      "presentment_money": {
                        "amount": "20.15",
                        "currency_code": "EUR"
                      },
                      "shop_money": {
                        "amount": "25.81",
                        "currency_code": "USD"
                      }
                    },
                    "rate": 0.13,
                    "title": "HST"
                  }
                ],
                "taxable": true,
                "title": "IPod Nano",
                "total_discount": "5.00",
                "total_discount_set": {
                  "presentment_money": {
                    "amount": "4.30",
                    "currency_code": "EUR"
                  },
                  "shop_money": {
                    "amount": "5.00",
                    "currency_code": "USD"
                  }
                },
                "variant_id": 4264112,
                "variant_title": "Pink",
                "vendor": "Apple"
              }
            ],
            "location_id": 49202758,
            "name": "#1001",
            "note": "Customer changed their mind.",
            "note_attributes": [
              {
                "name": "custom name",
                "value": "custom value"
              }
            ],
            "number": 1,
            "order_number": 1001,
            "order_status_url": "https://checkout.shopify.com/112233/checkouts/4207896aad57dfb159/thank_you_token?key=753621327b9e8a64789651bf221dfe35",
            "original_total_duties_set": {
              "presentment_money": {
                "amount": "105.31",
                "currency_code": "EUR"
              },
              "shop_money": {
                "amount": "164.86",
                "currency_code": "CAD"
              }
            },
            "payment_details": {
              "avs_result_code": "Y",
              "credit_card_bin": "453600",
              "credit_card_company": "Visa",
              "credit_card_number": "•••• •••• •••• 4242",
              "cvv_result_code": "M"
            },
            "payment_gateway_names": [
              "authorize_net",
              "Cash on Delivery (COD)"
            ],
            "phone": "+557734881234",
            "presentment_currency": "CAD",
            "processed_at": "2008-01-10T11:00:00-05:00",
            "processing_method": "direct",
            "referring_site": "http://www.anexample.com",
            "refunds": [
              {
                "created_at": "2018-03-06T09:35:37-05:00",
                "id": 18423447608,
                "note": null,
                "order_adjustments": [],
                "order_id": 394481795128,
                "processed_at": "2018-03-06T09:35:37-05:00",
                "refund_line_items": [],
                "transactions": [],
                "user_id": null
              }
            ],
            "shipping_address": {
              "address1": "123 Amoebobacterieae St",
              "address2": "",
              "city": "Ottawa",
              "company": null,
              "country": "Canada",
              "country_code": "CA",
              "first_name": "Bob",
              "last_name": "Bobsen",
              "latitude": "45.41634",
              "longitude": "-75.6868",
              "name": "Bob Bobsen",
              "phone": "555-625-1199",
              "province": "Ontario",
              "province_code": "ON",
              "zip": "K2P0V6"
            },
            "shipping_lines": [
              {
                "carrier_identifier": "third_party_carrier_identifier",
                "code": "INT.TP",
                "discounted_price": "4.00",
                "discounted_price_set": {
                  "presentment_money": {
                    "amount": "3.17",
                    "currency_code": "EUR"
                  },
                  "shop_money": {
                    "amount": "4.00",
                    "currency_code": "USD"
                  }
                },
                "price": "4.00",
                "price_set": {
                  "presentment_money": {
                    "amount": "3.17",
                    "currency_code": "EUR"
                  },
                  "shop_money": {
                    "amount": "4.00",
                    "currency_code": "USD"
                  }
                },
                "requested_fulfillment_service_id": "third_party_fulfillment_service_id",
                "source": "canada_post",
                "tax_lines": [],
                "title": "Small Packet International Air"
              }
            ],
            "source_name": "web",
            "subtotal_price": 398.0,
            "subtotal_price_set": {
              "presentment_money": {
                "amount": "90.95",
                "currency_code": "EUR"
              },
              "shop_money": {
                "amount": "141.99",
                "currency_code": "CAD"
              }
            },
            "tags": "imported",
            "tax_lines": [
              {
                "price": 11.94,
                "rate": 0.06,
                "title": "State Tax"
              }
            ],
            "taxes_included": false,
            "test": true,
            "token": "b1946ac92492d2347c6235b4d2611184",
            "total_discounts": "0.00",
            "total_discounts_set": {
              "presentment_money": {
                "amount": "0.00",
                "currency_code": "EUR"
              },
              "shop_money": {
                "amount": "0.00",
                "currency_code": "CAD"
              }
            },
            "total_line_items_price": "398.00",
            "total_line_items_price_set": {
              "presentment_money": {
                "amount": "90.95",
                "currency_code": "EUR"
              },
              "shop_money": {
                "amount": "141.99",
                "currency_code": "CAD"
              }
            },
            "total_outstanding": "5.00",
            "total_price": "409.94",
            "total_price_set": {
              "presentment_money": {
                "amount": "105.31",
                "currency_code": "EUR"
              },
              "shop_money": {
                "amount": "164.86",
                "currency_code": "CAD"
              }
            },
            "total_shipping_price_set": {
              "presentment_money": {
                "amount": "0.00",
                "currency_code": "USD"
              },
              "shop_money": {
                "amount": "30.00",
                "currency_code": "USD"
              }
            },
            "total_tax": "11.94",
            "total_tax_set": {
              "presentment_money": {
                "amount": "11.82",
                "currency_code": "EUR"
              },
              "shop_money": {
                "amount": "18.87",
                "currency_code": "CAD"
              }
            },
            "total_tip_received": "4.87",
            "total_weight": 300,
            "updated_at": "2012-08-25T14:02:15-04:00",
            "user_id": 31522279
          }
        J
      end
    end

    it_behaves_like "a service implementation that can backfill", "shopify_order_v1" do
      let(:today) { Time.parse("2020-11-22T18:00:00Z") }

      let(:page1_items) { [{}, {}] }
      let(:page2_items) { [{}] }
      let(:page1_response) do
        <<~R
          {
            "orders": [
              {
                "id": 100000000,
                "email": "bob.norman@hostmail.com",
                "closed_at": null,
                "created_at": "2008-01-10T11:00:00-05:00",
                "updated_at": "2008-01-10T11:00:00-05:00",
                "number": 1,
                "note": null,
                "token": "b1946ac92492d2347c6235b4d2611184",
                "gateway": "authorize_net",
                "test": false,
                "total_price": "598.94",
                "subtotal_price": "597.00",
                "total_weight": 0,
                "total_tax": "11.94",
                "taxes_included": false,
                "currency": "USD",
                "financial_status": "partially_refunded",
                "confirmed": true,
                "total_discounts": "10.00",
                "total_line_items_price": "597.00",
                "cart_token": "68778783ad298f1c80c3bafcddeea02f",
                "buyer_accepts_marketing": false,
                "name": "#1001",
                "referring_site": "http://www.otherexample.com",
                "landing_site": "http://www.example.com?source=abc",
                "cancelled_at": null,
                "cancel_reason": null,
                "total_price_usd": "598.94",
                "checkout_token": "bd5a8aa1ecd019dd3520ff791ee3a24c",
                "reference": "fhwdgads",
                "user_id": null,
                "location_id": null,
                "source_identifier": "fhwdgads",
                "source_url": null,
                "processed_at": "2008-01-10T11:00:00-05:00",
                "device_id": null,
                "phone": "+557734881234",
                "customer_locale": null,
                "app_id": null,
                "browser_ip": "0.0.0.0",
                "client_details": {
                  "accept_language": null,
                  "browser_height": null,
                  "browser_ip": "0.0.0.0",
                  "browser_width": null,
                  "session_hash": null,
                  "user_agent": null
                },
                "landing_site_ref": "abc",
                "order_number": 1001,
                "discount_applications": [
                  {
                    "type": "discount_code",
                    "value": "10.0",
                    "value_type": "fixed_amount",
                    "allocation_method": "across",
                    "target_selection": "all",
                    "target_type": "line_item",
                    "code": "TENOFF"
                  }
                ],
                "discount_codes": [
                  {
                    "code": "TENOFF",
                    "amount": "10.00",
                    "type": "fixed_amount"
                  }
                ],
                "note_attributes": [
                  {
                    "name": "custom engraving",
                    "value": "Happy Birthday"
                  },
                  {
                    "name": "colour",
                    "value": "green"
                  }
                ],
                "payment_details": {
                  "credit_card_bin": null,
                  "avs_result_code": null,
                  "cvv_result_code": null,
                  "credit_card_number": "•••• •••• •••• 4242",
                  "credit_card_company": "Visa"
                },
                "payment_gateway_names": [
                  "bogus"
                ],
                "processing_method": "direct",
                "checkout_id": 901414060,
                "source_name": "web",
                "fulfillment_status": null,
                "tax_lines": [
                  {
                    "price": "11.94",
                    "rate": 0.06,
                    "title": "State Tax",
                    "price_set": {
                      "shop_money": {
                        "amount": "11.94",
                        "currency_code": "USD"
                      },
                      "presentment_money": {
                        "amount": "11.94",
                        "currency_code": "USD"
                      }
                    }
                  }
                ],
                "tags": "",
                "contact_email": "bob.norman@hostmail.com",
                "order_status_url": "https://apple.myshopify.com/690933842/orders/b1946ac92492d2347c6235b4d2611184/authenticate?key=c3ed2ae86bc664ccdd9355e1bbeb76ea",
                "presentment_currency": "USD",
                "total_line_items_price_set": {
                  "shop_money": {
                    "amount": "597.00",
                    "currency_code": "USD"
                  },
                  "presentment_money": {
                    "amount": "597.00",
                    "currency_code": "USD"
                  }
                },
                "total_discounts_set": {
                  "shop_money": {
                    "amount": "10.00",
                    "currency_code": "USD"
                  },
                  "presentment_money": {
                    "amount": "10.00",
                    "currency_code": "USD"
                  }
                },
                "total_shipping_price_set": {
                  "shop_money": {
                    "amount": "0.00",
                    "currency_code": "USD"
                  },
                  "presentment_money": {
                    "amount": "0.00",
                    "currency_code": "USD"
                  }
                },
                "subtotal_price_set": {
                  "shop_money": {
                    "amount": "597.00",
                    "currency_code": "USD"
                  },
                  "presentment_money": {
                    "amount": "597.00",
                    "currency_code": "USD"
                  }
                },
                "total_price_set": {
                  "shop_money": {
                    "amount": "598.94",
                    "currency_code": "USD"
                  },
                  "presentment_money": {
                    "amount": "598.94",
                    "currency_code": "USD"
                  }
                },
                "total_tax_set": {
                  "shop_money": {
                    "amount": "11.94",
                    "currency_code": "USD"
                  },
                  "presentment_money": {
                    "amount": "11.94",
                    "currency_code": "USD"
                  }
                },
                "line_items": [
                  {
                    "id": 466157049,
                    "variant_id": 39072856,
                    "title": "IPod Nano - 8gb",
                    "quantity": 1,
                    "sku": "IPOD2008GREEN",
                    "variant_title": "green",
                    "vendor": null,
                    "fulfillment_service": "manual",
                    "product_id": 632910392,
                    "requires_shipping": true,
                    "taxable": true,
                    "gift_card": false,
                    "name": "IPod Nano - 8gb - green",
                    "variant_inventory_management": "shopify",
                    "properties": [
                      {
                        "name": "Custom Engraving Front",
                        "value": "Happy Birthday"
                      },
                      {
                        "name": "Custom Engraving Back",
                        "value": "Merry Christmas"
                      }
                    ],
                    "product_exists": true,
                    "fulfillable_quantity": 1,
                    "grams": 200,
                    "price": "199.00",
                    "total_discount": "0.00",
                    "fulfillment_status": null,
                    "price_set": {
                      "shop_money": {
                        "amount": "199.00",
                        "currency_code": "USD"
                      },
                      "presentment_money": {
                        "amount": "199.00",
                        "currency_code": "USD"
                      }
                    },
                    "total_discount_set": {
                      "shop_money": {
                        "amount": "0.00",
                        "currency_code": "USD"
                      },
                      "presentment_money": {
                        "amount": "0.00",
                        "currency_code": "USD"
                      }
                    },
                    "discount_allocations": [
                      {
                        "amount": "3.34",
                        "discount_application_index": 0,
                        "amount_set": {
                          "shop_money": {
                            "amount": "3.34",
                            "currency_code": "USD"
                          },
                          "presentment_money": {
                            "amount": "3.34",
                            "currency_code": "USD"
                          }
                        }
                      }
                    ],
                    "admin_graphql_api_id": "gid://shopify/LineItem/466157049",
                    "tax_lines": [
                      {
                        "title": "State Tax",
                        "price": "3.98",
                        "rate": 0.06,
                        "price_set": {
                          "shop_money": {
                            "amount": "3.98",
                            "currency_code": "USD"
                          },
                          "presentment_money": {
                            "amount": "3.98",
                            "currency_code": "USD"
                          }
                        }
                      }
                    ]
                  },
                  {
                    "id": 518995019,
                    "variant_id": 49148385,
                    "title": "IPod Nano - 8gb",
                    "quantity": 1,
                    "sku": "IPOD2008RED",
                    "variant_title": "red",
                    "vendor": null,
                    "fulfillment_service": "manual",
                    "product_id": 632910392,
                    "requires_shipping": true,
                    "taxable": true,
                    "gift_card": false,
                    "name": "IPod Nano - 8gb - red",
                    "variant_inventory_management": "shopify",
                    "properties": [],
                    "product_exists": true,
                    "fulfillable_quantity": 1,
                    "grams": 200,
                    "price": "199.00",
                    "total_discount": "0.00",
                    "fulfillment_status": null,
                    "price_set": {
                      "shop_money": {
                        "amount": "199.00",
                        "currency_code": "USD"
                      },
                      "presentment_money": {
                        "amount": "199.00",
                        "currency_code": "USD"
                      }
                    },
                    "total_discount_set": {
                      "shop_money": {
                        "amount": "0.00",
                        "currency_code": "USD"
                      },
                      "presentment_money": {
                        "amount": "0.00",
                        "currency_code": "USD"
                      }
                    },
                    "discount_allocations": [
                      {
                        "amount": "3.33",
                        "discount_application_index": 0,
                        "amount_set": {
                          "shop_money": {
                            "amount": "3.33",
                            "currency_code": "USD"
                          },
                          "presentment_money": {
                            "amount": "3.33",
                            "currency_code": "USD"
                          }
                        }
                      }
                    ],
                    "admin_graphql_api_id": "gid://shopify/LineItem/518995019",
                    "tax_lines": [
                      {
                        "title": "State Tax",
                        "price": "3.98",
                        "rate": 0.06,
                        "price_set": {
                          "shop_money": {
                            "amount": "3.98",
                            "currency_code": "USD"
                          },
                          "presentment_money": {
                            "amount": "3.98",
                            "currency_code": "USD"
                          }
                        }
                      }
                    ]
                  },
                  {
                    "id": 703073504,
                    "variant_id": 457924702,
                    "title": "IPod Nano - 8gb",
                    "quantity": 1,
                    "sku": "IPOD2008BLACK",
                    "variant_title": "black",
                    "vendor": null,
                    "fulfillment_service": "manual",
                    "product_id": 632910392,
                    "requires_shipping": true,
                    "taxable": true,
                    "gift_card": false,
                    "name": "IPod Nano - 8gb - black",
                    "variant_inventory_management": "shopify",
                    "properties": [],
                    "product_exists": true,
                    "fulfillable_quantity": 1,
                    "grams": 200,
                    "price": "199.00",
                    "total_discount": "0.00",
                    "fulfillment_status": null,
                    "price_set": {
                      "shop_money": {
                        "amount": "199.00",
                        "currency_code": "USD"
                      },
                      "presentment_money": {
                        "amount": "199.00",
                        "currency_code": "USD"
                      }
                    },
                    "total_discount_set": {
                      "shop_money": {
                        "amount": "0.00",
                        "currency_code": "USD"
                      },
                      "presentment_money": {
                        "amount": "0.00",
                        "currency_code": "USD"
                      }
                    },
                    "discount_allocations": [
                      {
                        "amount": "3.33",
                        "discount_application_index": 0,
                        "amount_set": {
                          "shop_money": {
                            "amount": "3.33",
                            "currency_code": "USD"
                          },
                          "presentment_money": {
                            "amount": "3.33",
                            "currency_code": "USD"
                          }
                        }
                      }
                    ],
                    "admin_graphql_api_id": "gid://shopify/LineItem/703073504",
                    "tax_lines": [
                      {
                        "title": "State Tax",
                        "price": "3.98",
                        "rate": 0.06,
                        "price_set": {
                          "shop_money": {
                            "amount": "3.98",
                            "currency_code": "USD"
                          },
                          "presentment_money": {
                            "amount": "3.98",
                            "currency_code": "USD"
                          }
                        }
                      }
                    ]
                  }
                ],
                "fulfillments": [
                  {
                    "id": 255858046,
                    "order_id": 450789469,
                    "status": "failure",
                    "created_at": "2021-04-13T17:23:20-04:00",
                    "service": "manual",
                    "updated_at": "2021-04-13T17:23:20-04:00",
                    "tracking_company": "USPS",
                    "shipment_status": null,
                    "location_id": 905684977,
                    "line_items": [
                      {
                        "id": 466157049,
                        "variant_id": 39072856,
                        "title": "IPod Nano - 8gb",
                        "quantity": 1,
                        "sku": "IPOD2008GREEN",
                        "variant_title": "green",
                        "vendor": null,
                        "fulfillment_service": "manual",
                        "product_id": 632910392,
                        "requires_shipping": true,
                        "taxable": true,
                        "gift_card": false,
                        "name": "IPod Nano - 8gb - green",
                        "variant_inventory_management": "shopify",
                        "properties": [
                          {
                            "name": "Custom Engraving Front",
                            "value": "Happy Birthday"
                          },
                          {
                            "name": "Custom Engraving Back",
                            "value": "Merry Christmas"
                          }
                        ],
                        "product_exists": true,
                        "fulfillable_quantity": 1,
                        "grams": 200,
                        "price": "199.00",
                        "total_discount": "0.00",
                        "fulfillment_status": null,
                        "price_set": {
                          "shop_money": {
                            "amount": "199.00",
                            "currency_code": "USD"
                          },
                          "presentment_money": {
                            "amount": "199.00",
                            "currency_code": "USD"
                          }
                        },
                        "total_discount_set": {
                          "shop_money": {
                            "amount": "0.00",
                            "currency_code": "USD"
                          },
                          "presentment_money": {
                            "amount": "0.00",
                            "currency_code": "USD"
                          }
                        },
                        "discount_allocations": [
                          {
                            "amount": "3.34",
                            "discount_application_index": 0,
                            "amount_set": {
                              "shop_money": {
                                "amount": "3.34",
                                "currency_code": "USD"
                              },
                              "presentment_money": {
                                "amount": "3.34",
                                "currency_code": "USD"
                              }
                            }
                          }
                        ],
                        "admin_graphql_api_id": "gid://shopify/LineItem/466157049",
                        "tax_lines": [
                          {
                            "title": "State Tax",
                            "price": "3.98",
                            "rate": 0.06,
                            "price_set": {
                              "shop_money": {
                                "amount": "3.98",
                                "currency_code": "USD"
                              },
                              "presentment_money": {
                                "amount": "3.98",
                                "currency_code": "USD"
                              }
                            }
                          }
                        ]
                      }
                    ],
                    "tracking_number": "1Z2345",
                    "tracking_numbers": [
                      "1Z2345"
                    ],
                    "tracking_url": "https://tools.usps.com/go/TrackConfirmAction_input?qtc_tLabels1=1Z2345",
                    "tracking_urls": [
                      "https://tools.usps.com/go/TrackConfirmAction_input?qtc_tLabels1=1Z2345"
                    ],
                    "receipt": {
                      "testcase": true,
                      "authorization": "123456"
                    },
                    "name": "#1001.0",
                    "admin_graphql_api_id": "gid://shopify/Fulfillment/255858046"
                  }
                ],
                "refunds": [
                  {
                    "id": 509562969,
                    "order_id": 450789469,
                    "created_at": "2021-04-13T17:23:20-04:00",
                    "note": "it broke during shipping",
                    "user_id": 799407056,
                    "processed_at": "2021-04-13T17:23:20-04:00",
                    "restock": true,
                    "admin_graphql_api_id": "gid://shopify/Refund/509562969",
                    "refund_line_items": [
                      {
                        "id": 104689539,
                        "quantity": 1,
                        "line_item_id": 703073504,
                        "location_id": 487838322,
                        "restock_type": "legacy_restock",
                        "subtotal": 195.67,
                        "total_tax": 3.98,
                        "subtotal_set": {
                          "shop_money": {
                            "amount": "195.67",
                            "currency_code": "USD"
                          },
                          "presentment_money": {
                            "amount": "195.67",
                            "currency_code": "USD"
                          }
                        },
                        "total_tax_set": {
                          "shop_money": {
                            "amount": "3.98",
                            "currency_code": "USD"
                          },
                          "presentment_money": {
                            "amount": "3.98",
                            "currency_code": "USD"
                          }
                        },
                        "line_item": {
                          "id": 703073504,
                          "variant_id": 457924702,
                          "title": "IPod Nano - 8gb",
                          "quantity": 1,
                          "sku": "IPOD2008BLACK",
                          "variant_title": "black",
                          "vendor": null,
                          "fulfillment_service": "manual",
                          "product_id": 632910392,
                          "requires_shipping": true,
                          "taxable": true,
                          "gift_card": false,
                          "name": "IPod Nano - 8gb - black",
                          "variant_inventory_management": "shopify",
                          "properties": [],
                          "product_exists": true,
                          "fulfillable_quantity": 1,
                          "grams": 200,
                          "price": "199.00",
                          "total_discount": "0.00",
                          "fulfillment_status": null,
                          "price_set": {
                            "shop_money": {
                              "amount": "199.00",
                              "currency_code": "USD"
                            },
                            "presentment_money": {
                              "amount": "199.00",
                              "currency_code": "USD"
                            }
                          },
                          "total_discount_set": {
                            "shop_money": {
                              "amount": "0.00",
                              "currency_code": "USD"
                            },
                            "presentment_money": {
                              "amount": "0.00",
                              "currency_code": "USD"
                            }
                          },
                          "discount_allocations": [
                            {
                              "amount": "3.33",
                              "discount_application_index": 0,
                              "amount_set": {
                                "shop_money": {
                                  "amount": "3.33",
                                  "currency_code": "USD"
                                },
                                "presentment_money": {
                                  "amount": "3.33",
                                  "currency_code": "USD"
                                }
                              }
                            }
                          ],
                          "admin_graphql_api_id": "gid://shopify/LineItem/703073504",
                          "tax_lines": [
                            {
                              "title": "State Tax",
                              "price": "3.98",
                              "rate": 0.06,
                              "price_set": {
                                "shop_money": {
                                  "amount": "3.98",
                                  "currency_code": "USD"
                                },
                                "presentment_money": {
                                  "amount": "3.98",
                                  "currency_code": "USD"
                                }
                              }
                            }
                          ]
                        }
                      },
                      {
                        "id": 709875399,
                        "quantity": 1,
                        "line_item_id": 466157049,
                        "location_id": 487838322,
                        "restock_type": "legacy_restock",
                        "subtotal": 195.66,
                        "total_tax": 3.98,
                        "subtotal_set": {
                          "shop_money": {
                            "amount": "195.66",
                            "currency_code": "USD"
                          },
                          "presentment_money": {
                            "amount": "195.66",
                            "currency_code": "USD"
                          }
                        },
                        "total_tax_set": {
                          "shop_money": {
                            "amount": "3.98",
                            "currency_code": "USD"
                          },
                          "presentment_money": {
                            "amount": "3.98",
                            "currency_code": "USD"
                          }
                        },
                        "line_item": {
                          "id": 466157049,
                          "variant_id": 39072856,
                          "title": "IPod Nano - 8gb",
                          "quantity": 1,
                          "sku": "IPOD2008GREEN",
                          "variant_title": "green",
                          "vendor": null,
                          "fulfillment_service": "manual",
                          "product_id": 632910392,
                          "requires_shipping": true,
                          "taxable": true,
                          "gift_card": false,
                          "name": "IPod Nano - 8gb - green",
                          "variant_inventory_management": "shopify",
                          "properties": [
                            {
                              "name": "Custom Engraving Front",
                              "value": "Happy Birthday"
                            },
                            {
                              "name": "Custom Engraving Back",
                              "value": "Merry Christmas"
                            }
                          ],
                          "product_exists": true,
                          "fulfillable_quantity": 1,
                          "grams": 200,
                          "price": "199.00",
                          "total_discount": "0.00",
                          "fulfillment_status": null,
                          "price_set": {
                            "shop_money": {
                              "amount": "199.00",
                              "currency_code": "USD"
                            },
                            "presentment_money": {
                              "amount": "199.00",
                              "currency_code": "USD"
                            }
                          },
                          "total_discount_set": {
                            "shop_money": {
                              "amount": "0.00",
                              "currency_code": "USD"
                            },
                            "presentment_money": {
                              "amount": "0.00",
                              "currency_code": "USD"
                            }
                          },
                          "discount_allocations": [
                            {
                              "amount": "3.34",
                              "discount_application_index": 0,
                              "amount_set": {
                                "shop_money": {
                                  "amount": "3.34",
                                  "currency_code": "USD"
                                },
                                "presentment_money": {
                                  "amount": "3.34",
                                  "currency_code": "USD"
                                }
                              }
                            }
                          ],
                          "admin_graphql_api_id": "gid://shopify/LineItem/466157049",
                          "tax_lines": [
                            {
                              "title": "State Tax",
                              "price": "3.98",
                              "rate": 0.06,
                              "price_set": {
                                "shop_money": {
                                  "amount": "3.98",
                                  "currency_code": "USD"
                                },
                                "presentment_money": {
                                  "amount": "3.98",
                                  "currency_code": "USD"
                                }
                              }
                            }
                          ]
                        }
                      }
                    ],
                    "transactions": [
                      {
                        "id": 179259969,
                        "order_id": 450789469,
                        "kind": "refund",
                        "gateway": "bogus",
                        "status": "success",
                        "message": null,
                        "created_at": "2005-08-05T12:59:12-04:00",
                        "test": false,
                        "authorization": "authorization-key",
                        "location_id": null,
                        "user_id": null,
                        "parent_id": 801038806,
                        "processed_at": "2005-08-05T12:59:12-04:00",
                        "device_id": null,
                        "error_code": null,
                        "source_name": "web",
                        "receipt": {},
                        "amount": "209.00",
                        "currency": "USD",
                        "admin_graphql_api_id": "gid://shopify/OrderTransaction/179259969"
                      }
                    ],
                    "order_adjustments": []
                  }
                ],
                "total_tip_received": "0.0",
                "admin_graphql_api_id": "gid://shopify/Order/450789469",
                "shipping_lines": [
                  {
                    "id": 369256396,
                    "title": "Free Shipping",
                    "price": "0.00",
                    "code": "Free Shipping",
                    "source": "shopify",
                    "phone": null,
                    "requested_fulfillment_service_id": null,
                    "delivery_category": null,
                    "carrier_identifier": null,
                    "discounted_price": "0.00",
                    "price_set": {
                      "shop_money": {
                        "amount": "0.00",
                        "currency_code": "USD"
                      },
                      "presentment_money": {
                        "amount": "0.00",
                        "currency_code": "USD"
                      }
                    },
                    "discounted_price_set": {
                      "shop_money": {
                        "amount": "0.00",
                        "currency_code": "USD"
                      },
                      "presentment_money": {
                        "amount": "0.00",
                        "currency_code": "USD"
                      }
                    },
                    "discount_allocations": [],
                    "tax_lines": []
                  }
                ],
                "billing_address": {
                  "first_name": "Bob",
                  "address1": "Chestnut Street 92",
                  "phone": "555-625-1199",
                  "city": "Louisville",
                  "zip": "40202",
                  "province": "Kentucky",
                  "country": "United States",
                  "last_name": "Norman",
                  "address2": "",
                  "company": null,
                  "latitude": 45.41634,
                  "longitude": -75.6868,
                  "name": "Bob Norman",
                  "country_code": "US",
                  "province_code": "KY"
                },
                "shipping_address": {
                  "first_name": "Bob",
                  "address1": "Chestnut Street 92",
                  "phone": "555-625-1199",
                  "city": "Louisville",
                  "zip": "40202",
                  "province": "Kentucky",
                  "country": "United States",
                  "last_name": "Norman",
                  "address2": "",
                  "company": null,
                  "latitude": 45.41634,
                  "longitude": -75.6868,
                  "name": "Bob Norman",
                  "country_code": "US",
                  "province_code": "KY"
                },
                "customer": {
                  "id": 207119551,
                  "email": "bob.norman@hostmail.com",
                  "accepts_marketing": false,
                  "created_at": "2021-04-13T17:23:20-04:00",
                  "updated_at": "2021-04-13T17:23:20-04:00",
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
              }
            ]
          }
        R
      end
      let(:page2_response) do
        <<~R
          {
            "orders": [
              {
                "id": 200000000,
                "email": "bob.norman@hostmail.com",
                "closed_at": null,
                "created_at": "2008-01-10T11:00:00-05:00",
                "updated_at": "2008-01-10T11:00:00-05:00",
                "number": 1,
                "note": null,
                "token": "b1946ac92492d2347c6235b4d2611184",
                "gateway": "authorize_net",
                "test": false,
                "total_price": "598.94",
                "subtotal_price": "597.00",
                "total_weight": 0,
                "total_tax": "11.94",
                "taxes_included": false,
                "currency": "USD",
                "financial_status": "partially_refunded",
                "confirmed": true,
                "total_discounts": "10.00",
                "total_line_items_price": "597.00",
                "cart_token": "68778783ad298f1c80c3bafcddeea02f",
                "buyer_accepts_marketing": false,
                "name": "#1001",
                "referring_site": "http://www.otherexample.com",
                "landing_site": "http://www.example.com?source=abc",
                "cancelled_at": null,
                "cancel_reason": null,
                "total_price_usd": "598.94",
                "checkout_token": "bd5a8aa1ecd019dd3520ff791ee3a24c",
                "reference": "fhwdgads",
                "user_id": null,
                "location_id": null,
                "source_identifier": "fhwdgads",
                "source_url": null,
                "processed_at": "2008-01-10T11:00:00-05:00",
                "device_id": null,
                "phone": "+557734881234",
                "customer_locale": null,
                "app_id": null,
                "browser_ip": "0.0.0.0",
                "client_details": {
                  "accept_language": null,
                  "browser_height": null,
                  "browser_ip": "0.0.0.0",
                  "browser_width": null,
                  "session_hash": null,
                  "user_agent": null
                },
                "landing_site_ref": "abc",
                "order_number": 1001,
                "discount_applications": [
                  {
                    "type": "discount_code",
                    "value": "10.0",
                    "value_type": "fixed_amount",
                    "allocation_method": "across",
                    "target_selection": "all",
                    "target_type": "line_item",
                    "code": "TENOFF"
                  }
                ],
                "discount_codes": [
                  {
                    "code": "TENOFF",
                    "amount": "10.00",
                    "type": "fixed_amount"
                  }
                ],
                "note_attributes": [
                  {
                    "name": "custom engraving",
                    "value": "Happy Birthday"
                  },
                  {
                    "name": "colour",
                    "value": "green"
                  }
                ],
                "payment_details": {
                  "credit_card_bin": null,
                  "avs_result_code": null,
                  "cvv_result_code": null,
                  "credit_card_number": "•••• •••• •••• 4242",
                  "credit_card_company": "Visa"
                },
                "payment_gateway_names": [
                  "bogus"
                ],
                "processing_method": "direct",
                "checkout_id": 901414060,
                "source_name": "web",
                "fulfillment_status": null,
                "tax_lines": [
                  {
                    "price": "11.94",
                    "rate": 0.06,
                    "title": "State Tax",
                    "price_set": {
                      "shop_money": {
                        "amount": "11.94",
                        "currency_code": "USD"
                      },
                      "presentment_money": {
                        "amount": "11.94",
                        "currency_code": "USD"
                      }
                    }
                  }
                ],
                "tags": "",
                "contact_email": "bob.norman@hostmail.com",
                "order_status_url": "https://apple.myshopify.com/690933842/orders/b1946ac92492d2347c6235b4d2611184/authenticate?key=c3ed2ae86bc664ccdd9355e1bbeb76ea",
                "presentment_currency": "USD",
                "total_line_items_price_set": {
                  "shop_money": {
                    "amount": "597.00",
                    "currency_code": "USD"
                  },
                  "presentment_money": {
                    "amount": "597.00",
                    "currency_code": "USD"
                  }
                },
                "total_discounts_set": {
                  "shop_money": {
                    "amount": "10.00",
                    "currency_code": "USD"
                  },
                  "presentment_money": {
                    "amount": "10.00",
                    "currency_code": "USD"
                  }
                },
                "total_shipping_price_set": {
                  "shop_money": {
                    "amount": "0.00",
                    "currency_code": "USD"
                  },
                  "presentment_money": {
                    "amount": "0.00",
                    "currency_code": "USD"
                  }
                },
                "subtotal_price_set": {
                  "shop_money": {
                    "amount": "597.00",
                    "currency_code": "USD"
                  },
                  "presentment_money": {
                    "amount": "597.00",
                    "currency_code": "USD"
                  }
                },
                "total_price_set": {
                  "shop_money": {
                    "amount": "598.94",
                    "currency_code": "USD"
                  },
                  "presentment_money": {
                    "amount": "598.94",
                    "currency_code": "USD"
                  }
                },
                "total_tax_set": {
                  "shop_money": {
                    "amount": "11.94",
                    "currency_code": "USD"
                  },
                  "presentment_money": {
                    "amount": "11.94",
                    "currency_code": "USD"
                  }
                },
                "line_items": [
                  {
                    "id": 466157049,
                    "variant_id": 39072856,
                    "title": "IPod Nano - 8gb",
                    "quantity": 1,
                    "sku": "IPOD2008GREEN",
                    "variant_title": "green",
                    "vendor": null,
                    "fulfillment_service": "manual",
                    "product_id": 632910392,
                    "requires_shipping": true,
                    "taxable": true,
                    "gift_card": false,
                    "name": "IPod Nano - 8gb - green",
                    "variant_inventory_management": "shopify",
                    "properties": [
                      {
                        "name": "Custom Engraving Front",
                        "value": "Happy Birthday"
                      },
                      {
                        "name": "Custom Engraving Back",
                        "value": "Merry Christmas"
                      }
                    ],
                    "product_exists": true,
                    "fulfillable_quantity": 1,
                    "grams": 200,
                    "price": "199.00",
                    "total_discount": "0.00",
                    "fulfillment_status": null,
                    "price_set": {
                      "shop_money": {
                        "amount": "199.00",
                        "currency_code": "USD"
                      },
                      "presentment_money": {
                        "amount": "199.00",
                        "currency_code": "USD"
                      }
                    },
                    "total_discount_set": {
                      "shop_money": {
                        "amount": "0.00",
                        "currency_code": "USD"
                      },
                      "presentment_money": {
                        "amount": "0.00",
                        "currency_code": "USD"
                      }
                    },
                    "discount_allocations": [
                      {
                        "amount": "3.34",
                        "discount_application_index": 0,
                        "amount_set": {
                          "shop_money": {
                            "amount": "3.34",
                            "currency_code": "USD"
                          },
                          "presentment_money": {
                            "amount": "3.34",
                            "currency_code": "USD"
                          }
                        }
                      }
                    ],
                    "admin_graphql_api_id": "gid://shopify/LineItem/466157049",
                    "tax_lines": [
                      {
                        "title": "State Tax",
                        "price": "3.98",
                        "rate": 0.06,
                        "price_set": {
                          "shop_money": {
                            "amount": "3.98",
                            "currency_code": "USD"
                          },
                          "presentment_money": {
                            "amount": "3.98",
                            "currency_code": "USD"
                          }
                        }
                      }
                    ]
                  },
                  {
                    "id": 518995019,
                    "variant_id": 49148385,
                    "title": "IPod Nano - 8gb",
                    "quantity": 1,
                    "sku": "IPOD2008RED",
                    "variant_title": "red",
                    "vendor": null,
                    "fulfillment_service": "manual",
                    "product_id": 632910392,
                    "requires_shipping": true,
                    "taxable": true,
                    "gift_card": false,
                    "name": "IPod Nano - 8gb - red",
                    "variant_inventory_management": "shopify",
                    "properties": [],
                    "product_exists": true,
                    "fulfillable_quantity": 1,
                    "grams": 200,
                    "price": "199.00",
                    "total_discount": "0.00",
                    "fulfillment_status": null,
                    "price_set": {
                      "shop_money": {
                        "amount": "199.00",
                        "currency_code": "USD"
                      },
                      "presentment_money": {
                        "amount": "199.00",
                        "currency_code": "USD"
                      }
                    },
                    "total_discount_set": {
                      "shop_money": {
                        "amount": "0.00",
                        "currency_code": "USD"
                      },
                      "presentment_money": {
                        "amount": "0.00",
                        "currency_code": "USD"
                      }
                    },
                    "discount_allocations": [
                      {
                        "amount": "3.33",
                        "discount_application_index": 0,
                        "amount_set": {
                          "shop_money": {
                            "amount": "3.33",
                            "currency_code": "USD"
                          },
                          "presentment_money": {
                            "amount": "3.33",
                            "currency_code": "USD"
                          }
                        }
                      }
                    ],
                    "admin_graphql_api_id": "gid://shopify/LineItem/518995019",
                    "tax_lines": [
                      {
                        "title": "State Tax",
                        "price": "3.98",
                        "rate": 0.06,
                        "price_set": {
                          "shop_money": {
                            "amount": "3.98",
                            "currency_code": "USD"
                          },
                          "presentment_money": {
                            "amount": "3.98",
                            "currency_code": "USD"
                          }
                        }
                      }
                    ]
                  },
                  {
                    "id": 703073504,
                    "variant_id": 457924702,
                    "title": "IPod Nano - 8gb",
                    "quantity": 1,
                    "sku": "IPOD2008BLACK",
                    "variant_title": "black",
                    "vendor": null,
                    "fulfillment_service": "manual",
                    "product_id": 632910392,
                    "requires_shipping": true,
                    "taxable": true,
                    "gift_card": false,
                    "name": "IPod Nano - 8gb - black",
                    "variant_inventory_management": "shopify",
                    "properties": [],
                    "product_exists": true,
                    "fulfillable_quantity": 1,
                    "grams": 200,
                    "price": "199.00",
                    "total_discount": "0.00",
                    "fulfillment_status": null,
                    "price_set": {
                      "shop_money": {
                        "amount": "199.00",
                        "currency_code": "USD"
                      },
                      "presentment_money": {
                        "amount": "199.00",
                        "currency_code": "USD"
                      }
                    },
                    "total_discount_set": {
                      "shop_money": {
                        "amount": "0.00",
                        "currency_code": "USD"
                      },
                      "presentment_money": {
                        "amount": "0.00",
                        "currency_code": "USD"
                      }
                    },
                    "discount_allocations": [
                      {
                        "amount": "3.33",
                        "discount_application_index": 0,
                        "amount_set": {
                          "shop_money": {
                            "amount": "3.33",
                            "currency_code": "USD"
                          },
                          "presentment_money": {
                            "amount": "3.33",
                            "currency_code": "USD"
                          }
                        }
                      }
                    ],
                    "admin_graphql_api_id": "gid://shopify/LineItem/703073504",
                    "tax_lines": [
                      {
                        "title": "State Tax",
                        "price": "3.98",
                        "rate": 0.06,
                        "price_set": {
                          "shop_money": {
                            "amount": "3.98",
                            "currency_code": "USD"
                          },
                          "presentment_money": {
                            "amount": "3.98",
                            "currency_code": "USD"
                          }
                        }
                      }
                    ]
                  }
                ],
                "fulfillments": [
                  {
                    "id": 255858046,
                    "order_id": 450789469,
                    "status": "failure",
                    "created_at": "2021-04-13T17:23:20-04:00",
                    "service": "manual",
                    "updated_at": "2021-04-13T17:23:20-04:00",
                    "tracking_company": "USPS",
                    "shipment_status": null,
                    "location_id": 905684977,
                    "line_items": [
                      {
                        "id": 466157049,
                        "variant_id": 39072856,
                        "title": "IPod Nano - 8gb",
                        "quantity": 1,
                        "sku": "IPOD2008GREEN",
                        "variant_title": "green",
                        "vendor": null,
                        "fulfillment_service": "manual",
                        "product_id": 632910392,
                        "requires_shipping": true,
                        "taxable": true,
                        "gift_card": false,
                        "name": "IPod Nano - 8gb - green",
                        "variant_inventory_management": "shopify",
                        "properties": [
                          {
                            "name": "Custom Engraving Front",
                            "value": "Happy Birthday"
                          },
                          {
                            "name": "Custom Engraving Back",
                            "value": "Merry Christmas"
                          }
                        ],
                        "product_exists": true,
                        "fulfillable_quantity": 1,
                        "grams": 200,
                        "price": "199.00",
                        "total_discount": "0.00",
                        "fulfillment_status": null,
                        "price_set": {
                          "shop_money": {
                            "amount": "199.00",
                            "currency_code": "USD"
                          },
                          "presentment_money": {
                            "amount": "199.00",
                            "currency_code": "USD"
                          }
                        },
                        "total_discount_set": {
                          "shop_money": {
                            "amount": "0.00",
                            "currency_code": "USD"
                          },
                          "presentment_money": {
                            "amount": "0.00",
                            "currency_code": "USD"
                          }
                        },
                        "discount_allocations": [
                          {
                            "amount": "3.34",
                            "discount_application_index": 0,
                            "amount_set": {
                              "shop_money": {
                                "amount": "3.34",
                                "currency_code": "USD"
                              },
                              "presentment_money": {
                                "amount": "3.34",
                                "currency_code": "USD"
                              }
                            }
                          }
                        ],
                        "admin_graphql_api_id": "gid://shopify/LineItem/466157049",
                        "tax_lines": [
                          {
                            "title": "State Tax",
                            "price": "3.98",
                            "rate": 0.06,
                            "price_set": {
                              "shop_money": {
                                "amount": "3.98",
                                "currency_code": "USD"
                              },
                              "presentment_money": {
                                "amount": "3.98",
                                "currency_code": "USD"
                              }
                            }
                          }
                        ]
                      }
                    ],
                    "tracking_number": "1Z2345",
                    "tracking_numbers": [
                      "1Z2345"
                    ],
                    "tracking_url": "https://tools.usps.com/go/TrackConfirmAction_input?qtc_tLabels1=1Z2345",
                    "tracking_urls": [
                      "https://tools.usps.com/go/TrackConfirmAction_input?qtc_tLabels1=1Z2345"
                    ],
                    "receipt": {
                      "testcase": true,
                      "authorization": "123456"
                    },
                    "name": "#1001.0",
                    "admin_graphql_api_id": "gid://shopify/Fulfillment/255858046"
                  }
                ],
                "refunds": [
                  {
                    "id": 509562969,
                    "order_id": 450789469,
                    "created_at": "2021-04-13T17:23:20-04:00",
                    "note": "it broke during shipping",
                    "user_id": 799407056,
                    "processed_at": "2021-04-13T17:23:20-04:00",
                    "restock": true,
                    "admin_graphql_api_id": "gid://shopify/Refund/509562969",
                    "refund_line_items": [
                      {
                        "id": 104689539,
                        "quantity": 1,
                        "line_item_id": 703073504,
                        "location_id": 487838322,
                        "restock_type": "legacy_restock",
                        "subtotal": 195.67,
                        "total_tax": 3.98,
                        "subtotal_set": {
                          "shop_money": {
                            "amount": "195.67",
                            "currency_code": "USD"
                          },
                          "presentment_money": {
                            "amount": "195.67",
                            "currency_code": "USD"
                          }
                        },
                        "total_tax_set": {
                          "shop_money": {
                            "amount": "3.98",
                            "currency_code": "USD"
                          },
                          "presentment_money": {
                            "amount": "3.98",
                            "currency_code": "USD"
                          }
                        },
                        "line_item": {
                          "id": 703073504,
                          "variant_id": 457924702,
                          "title": "IPod Nano - 8gb",
                          "quantity": 1,
                          "sku": "IPOD2008BLACK",
                          "variant_title": "black",
                          "vendor": null,
                          "fulfillment_service": "manual",
                          "product_id": 632910392,
                          "requires_shipping": true,
                          "taxable": true,
                          "gift_card": false,
                          "name": "IPod Nano - 8gb - black",
                          "variant_inventory_management": "shopify",
                          "properties": [],
                          "product_exists": true,
                          "fulfillable_quantity": 1,
                          "grams": 200,
                          "price": "199.00",
                          "total_discount": "0.00",
                          "fulfillment_status": null,
                          "price_set": {
                            "shop_money": {
                              "amount": "199.00",
                              "currency_code": "USD"
                            },
                            "presentment_money": {
                              "amount": "199.00",
                              "currency_code": "USD"
                            }
                          },
                          "total_discount_set": {
                            "shop_money": {
                              "amount": "0.00",
                              "currency_code": "USD"
                            },
                            "presentment_money": {
                              "amount": "0.00",
                              "currency_code": "USD"
                            }
                          },
                          "discount_allocations": [
                            {
                              "amount": "3.33",
                              "discount_application_index": 0,
                              "amount_set": {
                                "shop_money": {
                                  "amount": "3.33",
                                  "currency_code": "USD"
                                },
                                "presentment_money": {
                                  "amount": "3.33",
                                  "currency_code": "USD"
                                }
                              }
                            }
                          ],
                          "admin_graphql_api_id": "gid://shopify/LineItem/703073504",
                          "tax_lines": [
                            {
                              "title": "State Tax",
                              "price": "3.98",
                              "rate": 0.06,
                              "price_set": {
                                "shop_money": {
                                  "amount": "3.98",
                                  "currency_code": "USD"
                                },
                                "presentment_money": {
                                  "amount": "3.98",
                                  "currency_code": "USD"
                                }
                              }
                            }
                          ]
                        }
                      },
                      {
                        "id": 709875399,
                        "quantity": 1,
                        "line_item_id": 466157049,
                        "location_id": 487838322,
                        "restock_type": "legacy_restock",
                        "subtotal": 195.66,
                        "total_tax": 3.98,
                        "subtotal_set": {
                          "shop_money": {
                            "amount": "195.66",
                            "currency_code": "USD"
                          },
                          "presentment_money": {
                            "amount": "195.66",
                            "currency_code": "USD"
                          }
                        },
                        "total_tax_set": {
                          "shop_money": {
                            "amount": "3.98",
                            "currency_code": "USD"
                          },
                          "presentment_money": {
                            "amount": "3.98",
                            "currency_code": "USD"
                          }
                        },
                        "line_item": {
                          "id": 466157049,
                          "variant_id": 39072856,
                          "title": "IPod Nano - 8gb",
                          "quantity": 1,
                          "sku": "IPOD2008GREEN",
                          "variant_title": "green",
                          "vendor": null,
                          "fulfillment_service": "manual",
                          "product_id": 632910392,
                          "requires_shipping": true,
                          "taxable": true,
                          "gift_card": false,
                          "name": "IPod Nano - 8gb - green",
                          "variant_inventory_management": "shopify",
                          "properties": [
                            {
                              "name": "Custom Engraving Front",
                              "value": "Happy Birthday"
                            },
                            {
                              "name": "Custom Engraving Back",
                              "value": "Merry Christmas"
                            }
                          ],
                          "product_exists": true,
                          "fulfillable_quantity": 1,
                          "grams": 200,
                          "price": "199.00",
                          "total_discount": "0.00",
                          "fulfillment_status": null,
                          "price_set": {
                            "shop_money": {
                              "amount": "199.00",
                              "currency_code": "USD"
                            },
                            "presentment_money": {
                              "amount": "199.00",
                              "currency_code": "USD"
                            }
                          },
                          "total_discount_set": {
                            "shop_money": {
                              "amount": "0.00",
                              "currency_code": "USD"
                            },
                            "presentment_money": {
                              "amount": "0.00",
                              "currency_code": "USD"
                            }
                          },
                          "discount_allocations": [
                            {
                              "amount": "3.34",
                              "discount_application_index": 0,
                              "amount_set": {
                                "shop_money": {
                                  "amount": "3.34",
                                  "currency_code": "USD"
                                },
                                "presentment_money": {
                                  "amount": "3.34",
                                  "currency_code": "USD"
                                }
                              }
                            }
                          ],
                          "admin_graphql_api_id": "gid://shopify/LineItem/466157049",
                          "tax_lines": [
                            {
                              "title": "State Tax",
                              "price": "3.98",
                              "rate": 0.06,
                              "price_set": {
                                "shop_money": {
                                  "amount": "3.98",
                                  "currency_code": "USD"
                                },
                                "presentment_money": {
                                  "amount": "3.98",
                                  "currency_code": "USD"
                                }
                              }
                            }
                          ]
                        }
                      }
                    ],
                    "transactions": [
                      {
                        "id": 179259969,
                        "order_id": 450789469,
                        "kind": "refund",
                        "gateway": "bogus",
                        "status": "success",
                        "message": null,
                        "created_at": "2005-08-05T12:59:12-04:00",
                        "test": false,
                        "authorization": "authorization-key",
                        "location_id": null,
                        "user_id": null,
                        "parent_id": 801038806,
                        "processed_at": "2005-08-05T12:59:12-04:00",
                        "device_id": null,
                        "error_code": null,
                        "source_name": "web",
                        "receipt": {},
                        "amount": "209.00",
                        "currency": "USD",
                        "admin_graphql_api_id": "gid://shopify/OrderTransaction/179259969"
                      }
                    ],
                    "order_adjustments": []
                  }
                ],
                "total_tip_received": "0.0",
                "admin_graphql_api_id": "gid://shopify/Order/450789469",
                "shipping_lines": [
                  {
                    "id": 369256396,
                    "title": "Free Shipping",
                    "price": "0.00",
                    "code": "Free Shipping",
                    "source": "shopify",
                    "phone": null,
                    "requested_fulfillment_service_id": null,
                    "delivery_category": null,
                    "carrier_identifier": null,
                    "discounted_price": "0.00",
                    "price_set": {
                      "shop_money": {
                        "amount": "0.00",
                        "currency_code": "USD"
                      },
                      "presentment_money": {
                        "amount": "0.00",
                        "currency_code": "USD"
                      }
                    },
                    "discounted_price_set": {
                      "shop_money": {
                        "amount": "0.00",
                        "currency_code": "USD"
                      },
                      "presentment_money": {
                        "amount": "0.00",
                        "currency_code": "USD"
                      }
                    },
                    "discount_allocations": [],
                    "tax_lines": []
                  }
                ],
                "billing_address": {
                  "first_name": "Bob",
                  "address1": "Chestnut Street 92",
                  "phone": "555-625-1199",
                  "city": "Louisville",
                  "zip": "40202",
                  "province": "Kentucky",
                  "country": "United States",
                  "last_name": "Norman",
                  "address2": "",
                  "company": null,
                  "latitude": 45.41634,
                  "longitude": -75.6868,
                  "name": "Bob Norman",
                  "country_code": "US",
                  "province_code": "KY"
                },
                "shipping_address": {
                  "first_name": "Bob",
                  "address1": "Chestnut Street 92",
                  "phone": "555-625-1199",
                  "city": "Louisville",
                  "zip": "40202",
                  "province": "Kentucky",
                  "country": "United States",
                  "last_name": "Norman",
                  "address2": "",
                  "company": null,
                  "latitude": 45.41634,
                  "longitude": -75.6868,
                  "name": "Bob Norman",
                  "country_code": "US",
                  "province_code": "KY"
                },
                "customer": {
                  "id": 207119551,
                  "email": "bob.norman@hostmail.com",
                  "accepts_marketing": false,
                  "created_at": "2021-04-13T17:23:20-04:00",
                  "updated_at": "2021-04-13T17:23:20-04:00",
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
              }
            ]
          }
        R
      end
      let(:page3_response) do
        <<~R
                    {
            "orders": [
              {
                "id": 300000000,
                "email": "bob.norman@hostmail.com",
                "closed_at": null,
                "created_at": "2008-01-10T11:00:00-05:00",
                "updated_at": "2008-01-10T11:00:00-05:00",
                "number": 1,
                "note": null,
                "token": "b1946ac92492d2347c6235b4d2611184",
                "gateway": "authorize_net",
                "test": false,
                "total_price": "598.94",
                "subtotal_price": "597.00",
                "total_weight": 0,
                "total_tax": "11.94",
                "taxes_included": false,
                "currency": "USD",
                "financial_status": "partially_refunded",
                "confirmed": true,
                "total_discounts": "10.00",
                "total_line_items_price": "597.00",
                "cart_token": "68778783ad298f1c80c3bafcddeea02f",
                "buyer_accepts_marketing": false,
                "name": "#1001",
                "referring_site": "http://www.otherexample.com",
                "landing_site": "http://www.example.com?source=abc",
                "cancelled_at": null,
                "cancel_reason": null,
                "total_price_usd": "598.94",
                "checkout_token": "bd5a8aa1ecd019dd3520ff791ee3a24c",
                "reference": "fhwdgads",
                "user_id": null,
                "location_id": null,
                "source_identifier": "fhwdgads",
                "source_url": null,
                "processed_at": "2008-01-10T11:00:00-05:00",
                "device_id": null,
                "phone": "+557734881234",
                "customer_locale": null,
                "app_id": null,
                "browser_ip": "0.0.0.0",
                "client_details": {
                  "accept_language": null,
                  "browser_height": null,
                  "browser_ip": "0.0.0.0",
                  "browser_width": null,
                  "session_hash": null,
                  "user_agent": null
                },
                "landing_site_ref": "abc",
                "order_number": 1001,
                "discount_applications": [
                  {
                    "type": "discount_code",
                    "value": "10.0",
                    "value_type": "fixed_amount",
                    "allocation_method": "across",
                    "target_selection": "all",
                    "target_type": "line_item",
                    "code": "TENOFF"
                  }
                ],
                "discount_codes": [
                  {
                    "code": "TENOFF",
                    "amount": "10.00",
                    "type": "fixed_amount"
                  }
                ],
                "note_attributes": [
                  {
                    "name": "custom engraving",
                    "value": "Happy Birthday"
                  },
                  {
                    "name": "colour",
                    "value": "green"
                  }
                ],
                "payment_details": {
                  "credit_card_bin": null,
                  "avs_result_code": null,
                  "cvv_result_code": null,
                  "credit_card_number": "•••• •••• •••• 4242",
                  "credit_card_company": "Visa"
                },
                "payment_gateway_names": [
                  "bogus"
                ],
                "processing_method": "direct",
                "checkout_id": 901414060,
                "source_name": "web",
                "fulfillment_status": null,
                "tax_lines": [
                  {
                    "price": "11.94",
                    "rate": 0.06,
                    "title": "State Tax",
                    "price_set": {
                      "shop_money": {
                        "amount": "11.94",
                        "currency_code": "USD"
                      },
                      "presentment_money": {
                        "amount": "11.94",
                        "currency_code": "USD"
                      }
                    }
                  }
                ],
                "tags": "",
                "contact_email": "bob.norman@hostmail.com",
                "order_status_url": "https://apple.myshopify.com/690933842/orders/b1946ac92492d2347c6235b4d2611184/authenticate?key=c3ed2ae86bc664ccdd9355e1bbeb76ea",
                "presentment_currency": "USD",
                "total_line_items_price_set": {
                  "shop_money": {
                    "amount": "597.00",
                    "currency_code": "USD"
                  },
                  "presentment_money": {
                    "amount": "597.00",
                    "currency_code": "USD"
                  }
                },
                "total_discounts_set": {
                  "shop_money": {
                    "amount": "10.00",
                    "currency_code": "USD"
                  },
                  "presentment_money": {
                    "amount": "10.00",
                    "currency_code": "USD"
                  }
                },
                "total_shipping_price_set": {
                  "shop_money": {
                    "amount": "0.00",
                    "currency_code": "USD"
                  },
                  "presentment_money": {
                    "amount": "0.00",
                    "currency_code": "USD"
                  }
                },
                "subtotal_price_set": {
                  "shop_money": {
                    "amount": "597.00",
                    "currency_code": "USD"
                  },
                  "presentment_money": {
                    "amount": "597.00",
                    "currency_code": "USD"
                  }
                },
                "total_price_set": {
                  "shop_money": {
                    "amount": "598.94",
                    "currency_code": "USD"
                  },
                  "presentment_money": {
                    "amount": "598.94",
                    "currency_code": "USD"
                  }
                },
                "total_tax_set": {
                  "shop_money": {
                    "amount": "11.94",
                    "currency_code": "USD"
                  },
                  "presentment_money": {
                    "amount": "11.94",
                    "currency_code": "USD"
                  }
                },
                "line_items": [
                  {
                    "id": 466157049,
                    "variant_id": 39072856,
                    "title": "IPod Nano - 8gb",
                    "quantity": 1,
                    "sku": "IPOD2008GREEN",
                    "variant_title": "green",
                    "vendor": null,
                    "fulfillment_service": "manual",
                    "product_id": 632910392,
                    "requires_shipping": true,
                    "taxable": true,
                    "gift_card": false,
                    "name": "IPod Nano - 8gb - green",
                    "variant_inventory_management": "shopify",
                    "properties": [
                      {
                        "name": "Custom Engraving Front",
                        "value": "Happy Birthday"
                      },
                      {
                        "name": "Custom Engraving Back",
                        "value": "Merry Christmas"
                      }
                    ],
                    "product_exists": true,
                    "fulfillable_quantity": 1,
                    "grams": 200,
                    "price": "199.00",
                    "total_discount": "0.00",
                    "fulfillment_status": null,
                    "price_set": {
                      "shop_money": {
                        "amount": "199.00",
                        "currency_code": "USD"
                      },
                      "presentment_money": {
                        "amount": "199.00",
                        "currency_code": "USD"
                      }
                    },
                    "total_discount_set": {
                      "shop_money": {
                        "amount": "0.00",
                        "currency_code": "USD"
                      },
                      "presentment_money": {
                        "amount": "0.00",
                        "currency_code": "USD"
                      }
                    },
                    "discount_allocations": [
                      {
                        "amount": "3.34",
                        "discount_application_index": 0,
                        "amount_set": {
                          "shop_money": {
                            "amount": "3.34",
                            "currency_code": "USD"
                          },
                          "presentment_money": {
                            "amount": "3.34",
                            "currency_code": "USD"
                          }
                        }
                      }
                    ],
                    "admin_graphql_api_id": "gid://shopify/LineItem/466157049",
                    "tax_lines": [
                      {
                        "title": "State Tax",
                        "price": "3.98",
                        "rate": 0.06,
                        "price_set": {
                          "shop_money": {
                            "amount": "3.98",
                            "currency_code": "USD"
                          },
                          "presentment_money": {
                            "amount": "3.98",
                            "currency_code": "USD"
                          }
                        }
                      }
                    ]
                  },
                  {
                    "id": 518995019,
                    "variant_id": 49148385,
                    "title": "IPod Nano - 8gb",
                    "quantity": 1,
                    "sku": "IPOD2008RED",
                    "variant_title": "red",
                    "vendor": null,
                    "fulfillment_service": "manual",
                    "product_id": 632910392,
                    "requires_shipping": true,
                    "taxable": true,
                    "gift_card": false,
                    "name": "IPod Nano - 8gb - red",
                    "variant_inventory_management": "shopify",
                    "properties": [],
                    "product_exists": true,
                    "fulfillable_quantity": 1,
                    "grams": 200,
                    "price": "199.00",
                    "total_discount": "0.00",
                    "fulfillment_status": null,
                    "price_set": {
                      "shop_money": {
                        "amount": "199.00",
                        "currency_code": "USD"
                      },
                      "presentment_money": {
                        "amount": "199.00",
                        "currency_code": "USD"
                      }
                    },
                    "total_discount_set": {
                      "shop_money": {
                        "amount": "0.00",
                        "currency_code": "USD"
                      },
                      "presentment_money": {
                        "amount": "0.00",
                        "currency_code": "USD"
                      }
                    },
                    "discount_allocations": [
                      {
                        "amount": "3.33",
                        "discount_application_index": 0,
                        "amount_set": {
                          "shop_money": {
                            "amount": "3.33",
                            "currency_code": "USD"
                          },
                          "presentment_money": {
                            "amount": "3.33",
                            "currency_code": "USD"
                          }
                        }
                      }
                    ],
                    "admin_graphql_api_id": "gid://shopify/LineItem/518995019",
                    "tax_lines": [
                      {
                        "title": "State Tax",
                        "price": "3.98",
                        "rate": 0.06,
                        "price_set": {
                          "shop_money": {
                            "amount": "3.98",
                            "currency_code": "USD"
                          },
                          "presentment_money": {
                            "amount": "3.98",
                            "currency_code": "USD"
                          }
                        }
                      }
                    ]
                  },
                  {
                    "id": 703073504,
                    "variant_id": 457924702,
                    "title": "IPod Nano - 8gb",
                    "quantity": 1,
                    "sku": "IPOD2008BLACK",
                    "variant_title": "black",
                    "vendor": null,
                    "fulfillment_service": "manual",
                    "product_id": 632910392,
                    "requires_shipping": true,
                    "taxable": true,
                    "gift_card": false,
                    "name": "IPod Nano - 8gb - black",
                    "variant_inventory_management": "shopify",
                    "properties": [],
                    "product_exists": true,
                    "fulfillable_quantity": 1,
                    "grams": 200,
                    "price": "199.00",
                    "total_discount": "0.00",
                    "fulfillment_status": null,
                    "price_set": {
                      "shop_money": {
                        "amount": "199.00",
                        "currency_code": "USD"
                      },
                      "presentment_money": {
                        "amount": "199.00",
                        "currency_code": "USD"
                      }
                    },
                    "total_discount_set": {
                      "shop_money": {
                        "amount": "0.00",
                        "currency_code": "USD"
                      },
                      "presentment_money": {
                        "amount": "0.00",
                        "currency_code": "USD"
                      }
                    },
                    "discount_allocations": [
                      {
                        "amount": "3.33",
                        "discount_application_index": 0,
                        "amount_set": {
                          "shop_money": {
                            "amount": "3.33",
                            "currency_code": "USD"
                          },
                          "presentment_money": {
                            "amount": "3.33",
                            "currency_code": "USD"
                          }
                        }
                      }
                    ],
                    "admin_graphql_api_id": "gid://shopify/LineItem/703073504",
                    "tax_lines": [
                      {
                        "title": "State Tax",
                        "price": "3.98",
                        "rate": 0.06,
                        "price_set": {
                          "shop_money": {
                            "amount": "3.98",
                            "currency_code": "USD"
                          },
                          "presentment_money": {
                            "amount": "3.98",
                            "currency_code": "USD"
                          }
                        }
                      }
                    ]
                  }
                ],
                "fulfillments": [
                  {
                    "id": 255858046,
                    "order_id": 450789469,
                    "status": "failure",
                    "created_at": "2021-04-13T17:23:20-04:00",
                    "service": "manual",
                    "updated_at": "2021-04-13T17:23:20-04:00",
                    "tracking_company": "USPS",
                    "shipment_status": null,
                    "location_id": 905684977,
                    "line_items": [
                      {
                        "id": 466157049,
                        "variant_id": 39072856,
                        "title": "IPod Nano - 8gb",
                        "quantity": 1,
                        "sku": "IPOD2008GREEN",
                        "variant_title": "green",
                        "vendor": null,
                        "fulfillment_service": "manual",
                        "product_id": 632910392,
                        "requires_shipping": true,
                        "taxable": true,
                        "gift_card": false,
                        "name": "IPod Nano - 8gb - green",
                        "variant_inventory_management": "shopify",
                        "properties": [
                          {
                            "name": "Custom Engraving Front",
                            "value": "Happy Birthday"
                          },
                          {
                            "name": "Custom Engraving Back",
                            "value": "Merry Christmas"
                          }
                        ],
                        "product_exists": true,
                        "fulfillable_quantity": 1,
                        "grams": 200,
                        "price": "199.00",
                        "total_discount": "0.00",
                        "fulfillment_status": null,
                        "price_set": {
                          "shop_money": {
                            "amount": "199.00",
                            "currency_code": "USD"
                          },
                          "presentment_money": {
                            "amount": "199.00",
                            "currency_code": "USD"
                          }
                        },
                        "total_discount_set": {
                          "shop_money": {
                            "amount": "0.00",
                            "currency_code": "USD"
                          },
                          "presentment_money": {
                            "amount": "0.00",
                            "currency_code": "USD"
                          }
                        },
                        "discount_allocations": [
                          {
                            "amount": "3.34",
                            "discount_application_index": 0,
                            "amount_set": {
                              "shop_money": {
                                "amount": "3.34",
                                "currency_code": "USD"
                              },
                              "presentment_money": {
                                "amount": "3.34",
                                "currency_code": "USD"
                              }
                            }
                          }
                        ],
                        "admin_graphql_api_id": "gid://shopify/LineItem/466157049",
                        "tax_lines": [
                          {
                            "title": "State Tax",
                            "price": "3.98",
                            "rate": 0.06,
                            "price_set": {
                              "shop_money": {
                                "amount": "3.98",
                                "currency_code": "USD"
                              },
                              "presentment_money": {
                                "amount": "3.98",
                                "currency_code": "USD"
                              }
                            }
                          }
                        ]
                      }
                    ],
                    "tracking_number": "1Z2345",
                    "tracking_numbers": [
                      "1Z2345"
                    ],
                    "tracking_url": "https://tools.usps.com/go/TrackConfirmAction_input?qtc_tLabels1=1Z2345",
                    "tracking_urls": [
                      "https://tools.usps.com/go/TrackConfirmAction_input?qtc_tLabels1=1Z2345"
                    ],
                    "receipt": {
                      "testcase": true,
                      "authorization": "123456"
                    },
                    "name": "#1001.0",
                    "admin_graphql_api_id": "gid://shopify/Fulfillment/255858046"
                  }
                ],
                "refunds": [
                  {
                    "id": 509562969,
                    "order_id": 450789469,
                    "created_at": "2021-04-13T17:23:20-04:00",
                    "note": "it broke during shipping",
                    "user_id": 799407056,
                    "processed_at": "2021-04-13T17:23:20-04:00",
                    "restock": true,
                    "admin_graphql_api_id": "gid://shopify/Refund/509562969",
                    "refund_line_items": [
                      {
                        "id": 104689539,
                        "quantity": 1,
                        "line_item_id": 703073504,
                        "location_id": 487838322,
                        "restock_type": "legacy_restock",
                        "subtotal": 195.67,
                        "total_tax": 3.98,
                        "subtotal_set": {
                          "shop_money": {
                            "amount": "195.67",
                            "currency_code": "USD"
                          },
                          "presentment_money": {
                            "amount": "195.67",
                            "currency_code": "USD"
                          }
                        },
                        "total_tax_set": {
                          "shop_money": {
                            "amount": "3.98",
                            "currency_code": "USD"
                          },
                          "presentment_money": {
                            "amount": "3.98",
                            "currency_code": "USD"
                          }
                        },
                        "line_item": {
                          "id": 703073504,
                          "variant_id": 457924702,
                          "title": "IPod Nano - 8gb",
                          "quantity": 1,
                          "sku": "IPOD2008BLACK",
                          "variant_title": "black",
                          "vendor": null,
                          "fulfillment_service": "manual",
                          "product_id": 632910392,
                          "requires_shipping": true,
                          "taxable": true,
                          "gift_card": false,
                          "name": "IPod Nano - 8gb - black",
                          "variant_inventory_management": "shopify",
                          "properties": [],
                          "product_exists": true,
                          "fulfillable_quantity": 1,
                          "grams": 200,
                          "price": "199.00",
                          "total_discount": "0.00",
                          "fulfillment_status": null,
                          "price_set": {
                            "shop_money": {
                              "amount": "199.00",
                              "currency_code": "USD"
                            },
                            "presentment_money": {
                              "amount": "199.00",
                              "currency_code": "USD"
                            }
                          },
                          "total_discount_set": {
                            "shop_money": {
                              "amount": "0.00",
                              "currency_code": "USD"
                            },
                            "presentment_money": {
                              "amount": "0.00",
                              "currency_code": "USD"
                            }
                          },
                          "discount_allocations": [
                            {
                              "amount": "3.33",
                              "discount_application_index": 0,
                              "amount_set": {
                                "shop_money": {
                                  "amount": "3.33",
                                  "currency_code": "USD"
                                },
                                "presentment_money": {
                                  "amount": "3.33",
                                  "currency_code": "USD"
                                }
                              }
                            }
                          ],
                          "admin_graphql_api_id": "gid://shopify/LineItem/703073504",
                          "tax_lines": [
                            {
                              "title": "State Tax",
                              "price": "3.98",
                              "rate": 0.06,
                              "price_set": {
                                "shop_money": {
                                  "amount": "3.98",
                                  "currency_code": "USD"
                                },
                                "presentment_money": {
                                  "amount": "3.98",
                                  "currency_code": "USD"
                                }
                              }
                            }
                          ]
                        }
                      },
                      {
                        "id": 709875399,
                        "quantity": 1,
                        "line_item_id": 466157049,
                        "location_id": 487838322,
                        "restock_type": "legacy_restock",
                        "subtotal": 195.66,
                        "total_tax": 3.98,
                        "subtotal_set": {
                          "shop_money": {
                            "amount": "195.66",
                            "currency_code": "USD"
                          },
                          "presentment_money": {
                            "amount": "195.66",
                            "currency_code": "USD"
                          }
                        },
                        "total_tax_set": {
                          "shop_money": {
                            "amount": "3.98",
                            "currency_code": "USD"
                          },
                          "presentment_money": {
                            "amount": "3.98",
                            "currency_code": "USD"
                          }
                        },
                        "line_item": {
                          "id": 466157049,
                          "variant_id": 39072856,
                          "title": "IPod Nano - 8gb",
                          "quantity": 1,
                          "sku": "IPOD2008GREEN",
                          "variant_title": "green",
                          "vendor": null,
                          "fulfillment_service": "manual",
                          "product_id": 632910392,
                          "requires_shipping": true,
                          "taxable": true,
                          "gift_card": false,
                          "name": "IPod Nano - 8gb - green",
                          "variant_inventory_management": "shopify",
                          "properties": [
                            {
                              "name": "Custom Engraving Front",
                              "value": "Happy Birthday"
                            },
                            {
                              "name": "Custom Engraving Back",
                              "value": "Merry Christmas"
                            }
                          ],
                          "product_exists": true,
                          "fulfillable_quantity": 1,
                          "grams": 200,
                          "price": "199.00",
                          "total_discount": "0.00",
                          "fulfillment_status": null,
                          "price_set": {
                            "shop_money": {
                              "amount": "199.00",
                              "currency_code": "USD"
                            },
                            "presentment_money": {
                              "amount": "199.00",
                              "currency_code": "USD"
                            }
                          },
                          "total_discount_set": {
                            "shop_money": {
                              "amount": "0.00",
                              "currency_code": "USD"
                            },
                            "presentment_money": {
                              "amount": "0.00",
                              "currency_code": "USD"
                            }
                          },
                          "discount_allocations": [
                            {
                              "amount": "3.34",
                              "discount_application_index": 0,
                              "amount_set": {
                                "shop_money": {
                                  "amount": "3.34",
                                  "currency_code": "USD"
                                },
                                "presentment_money": {
                                  "amount": "3.34",
                                  "currency_code": "USD"
                                }
                              }
                            }
                          ],
                          "admin_graphql_api_id": "gid://shopify/LineItem/466157049",
                          "tax_lines": [
                            {
                              "title": "State Tax",
                              "price": "3.98",
                              "rate": 0.06,
                              "price_set": {
                                "shop_money": {
                                  "amount": "3.98",
                                  "currency_code": "USD"
                                },
                                "presentment_money": {
                                  "amount": "3.98",
                                  "currency_code": "USD"
                                }
                              }
                            }
                          ]
                        }
                      }
                    ],
                    "transactions": [
                      {
                        "id": 179259969,
                        "order_id": 450789469,
                        "kind": "refund",
                        "gateway": "bogus",
                        "status": "success",
                        "message": null,
                        "created_at": "2005-08-05T12:59:12-04:00",
                        "test": false,
                        "authorization": "authorization-key",
                        "location_id": null,
                        "user_id": null,
                        "parent_id": 801038806,
                        "processed_at": "2005-08-05T12:59:12-04:00",
                        "device_id": null,
                        "error_code": null,
                        "source_name": "web",
                        "receipt": {},
                        "amount": "209.00",
                        "currency": "USD",
                        "admin_graphql_api_id": "gid://shopify/OrderTransaction/179259969"
                      }
                    ],
                    "order_adjustments": []
                  }
                ],
                "total_tip_received": "0.0",
                "admin_graphql_api_id": "gid://shopify/Order/450789469",
                "shipping_lines": [
                  {
                    "id": 369256396,
                    "title": "Free Shipping",
                    "price": "0.00",
                    "code": "Free Shipping",
                    "source": "shopify",
                    "phone": null,
                    "requested_fulfillment_service_id": null,
                    "delivery_category": null,
                    "carrier_identifier": null,
                    "discounted_price": "0.00",
                    "price_set": {
                      "shop_money": {
                        "amount": "0.00",
                        "currency_code": "USD"
                      },
                      "presentment_money": {
                        "amount": "0.00",
                        "currency_code": "USD"
                      }
                    },
                    "discounted_price_set": {
                      "shop_money": {
                        "amount": "0.00",
                        "currency_code": "USD"
                      },
                      "presentment_money": {
                        "amount": "0.00",
                        "currency_code": "USD"
                      }
                    },
                    "discount_allocations": [],
                    "tax_lines": []
                  }
                ],
                "billing_address": {
                  "first_name": "Bob",
                  "address1": "Chestnut Street 92",
                  "phone": "555-625-1199",
                  "city": "Louisville",
                  "zip": "40202",
                  "province": "Kentucky",
                  "country": "United States",
                  "last_name": "Norman",
                  "address2": "",
                  "company": null,
                  "latitude": 45.41634,
                  "longitude": -75.6868,
                  "name": "Bob Norman",
                  "country_code": "US",
                  "province_code": "KY"
                },
                "shipping_address": {
                  "first_name": "Bob",
                  "address1": "Chestnut Street 92",
                  "phone": "555-625-1199",
                  "city": "Louisville",
                  "zip": "40202",
                  "province": "Kentucky",
                  "country": "United States",
                  "last_name": "Norman",
                  "address2": "",
                  "company": null,
                  "latitude": 45.41634,
                  "longitude": -75.6868,
                  "name": "Bob Norman",
                  "country_code": "US",
                  "province_code": "KY"
                },
                "customer": {
                  "id": 207119551,
                  "email": "bob.norman@hostmail.com",
                  "accepts_marketing": false,
                  "created_at": "2021-04-13T17:23:20-04:00",
                  "updated_at": "2021-04-13T17:23:20-04:00",
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
      before(:each) do
        # rubocop:disable Layout/LineLength
        stub_request(:get, "https://fake-url.com/admin/api/2021-04/orders.json?status=any").
          with(
            headers: {
              "Accept" => "*/*",
              "Accept-Encoding" => "gzip;q=1.0,deflate;q=0.6,identity;q=0.3",
              "Authorization" => "Basic YmZrZXk6YmZzZWs=",
              "User-Agent" => "Ruby",
            },
          ).
          to_return(status: 200, body: page1_response,
                    headers: {"Content-Type" => "application/json",
                              "Link" => '<https://fake-url.com/admin/api/2021-04/orders.json?limit=2&page_info=abc123>; rel="next", <irrelevant_link>; rel="previous"',},)
        stub_request(:get, "https://fake-url.com/admin/api/2021-04/orders.json?limit=2&page_info=abc123").
          to_return(status: 200, body: page2_response,
                    headers: {"Content-Type" => "application/json",
                              "Link" => '<https://fake-url.com/admin/api/2021-04/orders.json?limit=2&page_info=xyz123>; rel="next", <irrelevant_link>; rel="previous"',},)
        stub_request(:get, "https://fake-url.com/admin/api/2021-04/orders.json?limit=2&page_info=xyz123").
          to_return(status: 200, body: page3_response,
                    headers: {"Content-Type" => "application/json",
                              "Link" => '<irrelevant_link>; rel="previous"',},)
        # rubocop:enable Layout/LineLength
      end
    end
    describe "webhook validation" do
      let(:sint) { Webhookdb::Fixtures.service_integration.create(service_name: "shopify_order_v1") }
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
    describe "state machine calculation" do
      let(:sint) do
        Webhookdb::Fixtures.service_integration.create(service_name: "shopify_order_v1", backfill_secret: "",
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
          state_machine = sint.calculate_create_state_machine
          expect(state_machine.needs_input).to eq(true)
          expect(state_machine.prompt).to eq("Paste or type your secret here:")
          expect(state_machine.prompt_is_secret).to eq(true)
          # rubocop:disable Layout/LineLength
          expect(state_machine.post_to_url).to eq("/v1/service_integrations/#{sint.opaque_id}/transition/webhook_secret")
          # rubocop:enable Layout/LineLength
          expect(state_machine.complete).to eq(false)
          expect(state_machine.output).to match("We've made an endpoint available for Shopify Order webhooks:")
        end

        it "confirms reciept of webhook secret, returns org database info" do
          sint.webhook_secret = "whsec_abcasdf"
          state_machine = sint.calculate_create_state_machine
          expect(state_machine.needs_input).to eq(false)
          expect(state_machine.prompt).to be_nil
          expect(state_machine.prompt_is_secret).to be_nil
          expect(state_machine.post_to_url).to be_nil
          expect(state_machine.complete).to eq(true)
          expect(state_machine.output).to match("Great! WebhookDB is now listening for Shopify Order webhooks.")
        end
      end
      describe "calculate_backfill_state_machine" do
        it "asks for backfill key" do
          state_machine = sint.calculate_backfill_state_machine
          expect(state_machine.needs_input).to eq(true)
          expect(state_machine.prompt).to eq("Paste or type your API Key here:")
          expect(state_machine.prompt_is_secret).to eq(true)
          expect(state_machine.post_to_url).to eq("/v1/service_integrations/#{sint.opaque_id}/transition/backfill_key")
          expect(state_machine.complete).to eq(false)
          expect(state_machine.output).to match(
            "In order to backfill Shopify Orders, we need an API key and password.",
          )
        end

        it "asks for backfill secret" do
          sint.backfill_key = "key_ghjkl"
          state_machine = sint.calculate_backfill_state_machine
          expect(state_machine.needs_input).to eq(true)
          expect(state_machine.prompt).to eq("Paste or type your password here:")
          expect(state_machine.prompt_is_secret).to eq(true)
          # rubocop:disable Layout/LineLength
          expect(state_machine.post_to_url).to eq("/v1/service_integrations/#{sint.opaque_id}/transition/backfill_secret")
          # rubocop:enable Layout/LineLength
          expect(state_machine.complete).to eq(false)
          expect(state_machine.output).to be_nil
        end

        it "asks for store name " do
          sint.backfill_key = "key_ghjkl"
          sint.backfill_secret = "whsec_abcasdf"
          state_machine = sint.calculate_backfill_state_machine
          expect(state_machine.needs_input).to eq(true)
          expect(state_machine.prompt).to match("Paste or type your shop name here:")
          expect(state_machine.prompt_is_secret).to eq(false)
          expect(state_machine.post_to_url).to eq("/v1/service_integrations/#{sint.opaque_id}/transition/shop_name")
          expect(state_machine.complete).to eq(false)
          expect(state_machine.output).to match(
            "Nice! Now we need the name of your shop so that we can construct the api url.",
          )
        end

        it "returns org database info" do
          sint.backfill_key = "key_ghjkl"
          sint.backfill_secret = "whsec_abcasdf"
          sint.api_url = "https://shopify_test.myshopify.com"
          state_machine = sint.calculate_backfill_state_machine
          expect(state_machine.needs_input).to eq(false)
          expect(state_machine.prompt).to be_nil
          expect(state_machine.prompt_is_secret).to be_nil
          expect(state_machine.post_to_url).to be_nil
          expect(state_machine.complete).to eq(true)
          expect(state_machine.output).to match(
            "Great! We are going to start backfilling your Shopify Order information.",
          )
        end
      end
    end
  end
end
