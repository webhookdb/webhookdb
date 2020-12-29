# frozen_string_literal: true

require "rspec"

RSpec.shared_examples "an endpoint with pagination" do
  let(:url) { raise "must be defined in block" }
  let(:make_item) { raise "must be defined in block" }
  let(:ok_status) { 200 }
  let(:http_method) { :get }

  it "accepts pagination params, and returns a list object" do
    items = Array.new(5) { |i| make_item(i) }

    send http_method, url, page: 2, per_page: 3

    expect(last_response).to have_status(ok_status)
    expect(last_response).to have_json_body.
      that_includes(
        object: "list",
        items: be_an_instance_of(Array),
        current_page: 2,
        page_count: 2,
        has_more: false,
      )
    expect(last_response_json_body[:items]).to have_same_ids_as(items[3..4])
  end

  it "has_more if there are more items" do
    items = Array.new(5) { |i| make_item(i) }

    send http_method, url, per_page: 2

    expect(last_response).to have_status(ok_status)
    expect(last_response).to have_json_body.
      that_includes(
        current_page: 1,
        page_count: 3,
        has_more: true,
      )
    expect(last_response_json_body[:items]).to have_same_ids_as(items[0..1])
  end
end

RSpec.shared_examples "an endpoint with customer-supplied ordering" do
  let(:url) { raise "must be defined in block" }
  let(:make_item) { raise "must be defined in block" }
  let(:order_by_field) { raise "must be defined in block" }
  let(:ok_status) { 200 }
  let(:http_method) { :get }

  it "defaults to a descending order" do
    items = Array.new(3) { |i| make_item(i) }

    send http_method, url, order_by: order_by_field

    expect(last_response).to have_status(ok_status)
    expect(last_response_json_body[:items]).to have_same_ids_as(items.reverse).ordered
  end

  it "can return items ordered ascending by the specified field" do
    items = Array.new(3) { |i| make_item(i) }

    send http_method, url, order_by: order_by_field, order_direction: "asc"

    expect(last_response).to have_status(ok_status)
    expect(last_response_json_body[:items]).to have_same_ids_as(items).ordered
  end

  it "can return items ordered descending by the specified field" do
    items = Array.new(3) { |i| make_item(i) }

    send http_method, url, order_by: order_by_field, order_direction: "desc"

    expect(last_response).to have_status(ok_status)
    expect(last_response_json_body[:items]).to have_same_ids_as(items.reverse).ordered
  end

  it "errors if the specified field is not supported" do
    send http_method, url, order_by: "invalid_field"

    expect(last_response).to have_status(400)
    expect(last_response.body).to include("order_by does not have a valid value")
  end
end

RSpec.shared_examples "an endpoint capable of search" do
  let(:url) { raise "must be defined in block" }
  let(:make_matching_items) { raise "must be defined in block" }
  let(:make_non_matching_items) { raise "must be defined in block" }
  let(:search_term) { raise "must be defined in block" }
  let(:ok_status) { 200 }
  let(:http_method) { :get }

  it "returns only matching items" do
    matched = make_matching_items
    unmatched = make_non_matching_items

    send http_method, url, search: search_term

    expect(last_response).to have_status(ok_status)
    expect(last_response_json_body[:items]).to have_same_ids_as(matched)
  end

  it "uses a case insensitive match" do
    matched = make_matching_items
    unmatched = make_non_matching_items

    rand_search = search_term.chars.map { |c| [c.upcase, c.downcase].sample }.join

    send http_method, url, search: rand_search

    expect(last_response).to have_status(ok_status)
    expect(last_response_json_body[:items]).to have_same_ids_as(matched)
  end

  it "returns all results with a whitespace string" do
    matched = make_matching_items
    unmatched = make_non_matching_items

    send http_method, url, search: "\t  \t"

    expect(last_response).to have_status(ok_status)
    expect(last_response_json_body[:items]).to have_same_ids_as(matched + unmatched)
  end

  it "returns all results with an asterik" do
    matched = make_matching_items
    unmatched = make_non_matching_items

    send http_method, url, search: "  *  "

    expect(last_response).to have_status(ok_status)
    expect(last_response_json_body[:items]).to have_same_ids_as(matched + unmatched)
  end
end
