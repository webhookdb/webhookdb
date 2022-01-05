# frozen_string_literal: true

require "rack/test"
require "raven"

require "webhookdb/api"

class Webhookdb::API::TestService < Webhookdb::Service
  format :json
  require "webhookdb/service/helpers"
  helpers Webhookdb::Service::Helpers
  include Webhookdb::Service::Types

  get :merror do
    merror!(403, "Hello!", code: "test_err", more: {doc_url: "http://some-place"})
  end

  params do
    requires :arg1
    requires :arg2
  end
  get :validation do
  end

  get :invalid_password do
    raise Webhookdb::Customer::InvalidPassword, "not a bunny"
  end

  get :invalid_plain do
    invalid!("this is invalid")
  end

  get :invalid_array do
    invalid!(["a is invalid", "b is invalid"])
  end

  params do
    requires :email, type: String, coerce_with: NormalizedEmail
    requires :phone, type: String, coerce_with: NormalizedPhone
    requires :arr, type: Array[String], coerce_with: CommaSepArray
  end
  get :custom_types do
    present({email: params[:email], phone: params[:phone], arr: params[:arr]})
  end

  get :lock_failed do
    raise Webhookdb::LockFailed
  end

  get :unhandled do
    1 / 0
  end

  get :hello do
    status 201
  end

  class CustomerEntity < Grape::Entity
    expose :id
    expose :note
  end

  get :collection_array do
    present_collection [1, 2, 3]
  end

  get :collection_dataset do
    present_collection Webhookdb::Customer.dataset, with: CustomerEntity
  end

  get :collection_direct do
    coll = Webhookdb::Service::Collection.new([5, 6, 7], current_page: 10, page_count: 20, total_count: 3,
                                                         last_page: false,)
    present_collection coll
  end

  get :caching do
    use_http_expires_caching(5.minutes)
    present [1, 2, 3]
  end

  class EtaggedEntity < Grape::Entity
    prepend Webhookdb::Service::Entities::EtaggedMixin
    expose :field1 do |_|
      25
    end
    expose :field2 do |_|
      "abcd"
    end
    expose :x
  end

  get :etagged do
    status 200
    present ({x: Date.new(2020, 4, 23)}), with: EtaggedEntity
  end

  get :rolecheck do
    check_role!(current_customer, "testing")
    status 200
  end
end

RSpec.describe Webhookdb::Service, :db do
  include Rack::Test::Methods

  before(:all) do
    @devmode = Webhookdb::Service.devmode
    @enforce_ssl = Webhookdb::Service.enforce_ssl
  end

  after(:all) do
    Webhookdb::Service.devmode = @devmode
    Webhookdb::Service.enforce_ssl = @enforce_ssl
  end

  before(:each) do
    Webhookdb::Service.devmode = true
    Webhookdb::Service.enforce_ssl = false
  end

  let(:app) { Webhookdb::API::TestService.build_app }

  it "redirects requests if SSL is enforced" do
    Webhookdb::Service.enforce_ssl = true

    get "/hello"
    expect(last_response).to have_status(301)
  end

  it "uses a consistent error shape for manual errors (merror!)" do
    get "/merror"
    expect(last_response).to have_status(403)
    expect(last_response_json_body).to eq(
      error: {doc_url: "http://some-place", message: "Hello!", status: 403, code: "test_err"},
    )
  end

  it "uses a consistent error shape for validation errors" do
    get "/validation"
    expect(last_response).to have_status(400)
    expect(last_response_json_body).to eq(
      error: {
        code: "validation_error",
        errors: ["arg1 is missing", "arg2 is missing"],
        # Upcase the first letter, since this is probably going into the UI.
        message: "Arg1 is missing, arg2 is missing",
        status: 400,
      },
    )

    get "/invalid_password"
    expect(last_response).to have_status(400)
    expect(last_response_json_body).to eq(
      error: {code: "validation_error", errors: ["not a bunny"], message: "Not a bunny", status: 400},
    )
  end

  it "derives a message from a validation error string" do
    get "/invalid_plain"
    expect(last_response).to have_status(400)
    expect(last_response_json_body).to eq(
      error: {code: "validation_error", errors: ["this is invalid"], message: "This is invalid", status: 400},
    )
  end

  it "derives a message from an array of validation errors" do
    get "/invalid_array"
    expect(last_response).to have_status(400)
    expect(last_response_json_body).to eq(
      error: {
        code: "validation_error",
        errors: ["a is invalid", "b is invalid"],
        message: "A is invalid, b is invalid",
        status: 400,
      },
    )
  end

  it "uses a consistent shape for LockFailed errors" do
    get "/lock_failed"
    expect(last_response).to have_status(409)
    expect(last_response_json_body).to match(
      error: hash_including(
        code: "lock_failed",
        status: 409,
      ),
    )
  end

  it "uses a consistent error shape for unhandled errors (devmode: off)" do
    Webhookdb::Raven.dsn = "foo"
    expect(Raven).to receive(:capture_exception)

    Webhookdb::Service.devmode = false

    get "/unhandled"

    expect(last_response).to have_status(500)
    expect(last_response_json_body).to match(error: match(
      error_id: match(/[a-z0-9-]+/),
      error_signature: match(/[a-z0-9]+/),
      message: match(/An internal error occurred of type [a-z0-9]+\. Error ID: [a-z0-9-]+/),
      status: 500,
      code: "api_error",
    ))
    expect(last_response_json_body[:error]).to_not include(:backtrace)
  end

  it "uses a consistent error shape for unhandled errors (devmode: on)" do
    Webhookdb::Service.devmode = true

    get "/unhandled"

    expect(last_response).to have_status(500)
    expect(last_response_json_body).to match(error: match(
      backtrace: %r{webhookdb/service_spec\.rb:},
      error_id: match(/[a-z0-9-]+/),
      error_signature: match(/[a-z0-9]+/),
      message: "divided by 0",
      status: 500,
      code: "api_error",
    ))
  end

  it "returns 405s as-is" do
    Webhookdb::Service.devmode = true

    put "/hello"

    expect(last_response).to have_status(405)
    expect(last_response).to have_json_body.that_includes(error: "405 Not Allowed")
  end

  it "always creates a session for unauthed customers" do
    get "/hello"

    expect(last_response).to have_status(201)
    expect(last_session_id).to be_present
  end

  describe "endpoint caching" do
    after(:all) do
      Webhookdb::Service.endpoint_caching = false
    end

    it "can cache via an Expires header" do
      Webhookdb::Service.endpoint_caching = true

      get "/caching"

      expect(last_response).to have_status(200)
      expect(last_response.headers).to include("Expires", "Cache-Control" => "public")
      expect(Time.parse(last_response.headers["Expires"])).to be_within(1.second).of(5.minutes.from_now)
    end

    it "does not cache if endpoint caching is disabled" do
      Webhookdb::Service.endpoint_caching = false

      get "/caching"

      expect(last_response).to have_status(200)
      expect(last_response.headers).to_not include("Expires")
    end
  end

  describe "collections" do
    it "can wrap an array of items" do
      get "/collection_array"

      expect(last_response).to have_status(200)
      expect(last_response_json_body).to include(
        object: "list",
        items: [1, 2, 3],
        current_page: 1,
        has_more: false,
        page_count: 1,
        total_count: 3,
      )
    end

    it "can wrap a Sequel dataset" do
      customer = Webhookdb::Fixtures.customer.create

      get "/collection_dataset"

      expect(last_response).to have_status(200)
      expect(last_response_json_body).to include(
        object: "list",
        items: [{id: customer.id, note: customer.note}],
        current_page: 1,
        has_more: false,
        page_count: 1,
        total_count: 1,
      )
    end

    it "can represent a Collection directly" do
      get "/collection_direct"

      expect(last_response).to have_status(200)
      expect(last_response_json_body).to include(
        object: "list",
        items: [5, 6, 7],
        current_page: 10,
        has_more: true,
        page_count: 20,
        total_count: 3,
      )
    end
  end

  it "adds CORS_ORIGINS env into configured origins" do
    described_class.cors_origins = ["a.b", "x.y", /webhookdb-web-staging(-pr-\d+)?\.herokuapp\.com/]
    described_class.run_after_configured_hooks
    expect(described_class.cors_origins).to include(
      /localhost:\d+/, "a.b", "x.y", /webhookdb-web-staging(-pr-\d+)?\.herokuapp\.com/,
    )
  end

  it "reports errors to sentry if devmode is off and raven is enabled" do
    Webhookdb::Service.devmode = false
    Webhookdb::Raven.dsn = "foo"
    expect(Raven).to receive(:capture_exception).
      with(ZeroDivisionError, tags: include(:error_id, :error_signature))

    get "/unhandled"
    expect(last_response).to have_status(500)
  end

  it "does not report errors to sentry if devmode is on and raven is enabled" do
    Webhookdb::Service.devmode = true
    Webhookdb::Raven.dsn = "foo"
    expect(Raven).to_not receive(:capture_exception)

    get "/unhandled"
    expect(last_response).to have_status(500)
  end

  it "does not report errors to sentry if devmode is on and raven is disabled" do
    Webhookdb::Service.devmode = true
    Webhookdb::Raven.reset_configuration
    expect(Raven).to_not receive(:capture_exception)

    get "/unhandled"
    expect(last_response).to have_status(500)
  end

  it "does not report errors to sentry if devmode is off and raven is disabled" do
    Webhookdb::Service.devmode = false
    Webhookdb::Raven.reset_configuration
    expect(Raven).to_not receive(:capture_exception)

    get "/unhandled"
    expect(last_response).to have_status(500)
  end

  it "captures context for unauthed customers" do
    get "/hello?world=1"

    expect(Raven.context.user).to include(ip_address: "127.0.0.1")
    expect(Raven.context.tags).to include(host: "example.org", method: "GET", path: "/hello", query: "world=1")
  end

  it "captures context for authed customers" do
    customer = Webhookdb::Fixtures.customer.create
    login_as(customer)

    get "/hello?world=1"

    expect(Raven.context.user).to include(
      ip_address: "127.0.0.1",
      id: customer.id,
      email: customer.email,
      name: customer.name,
    )
    expect(Raven.context.tags).to include(
      host: "example.org",
      method: "GET",
      path: "/hello",
      query: "world=1",
      "customer.email" => customer.email,
    )
  end

  describe "etag mixin" do
    it "hashes the rendered entity" do
      get "/etagged"

      expect(last_response).to have_status(200)
      expect(last_response.body).to eq(
        '{"field1":25,"field2":"abcd","x":"2020-04-23","etag":"db41e3e0da219ca43359a8581cdb74b1"}',
      )
    end
  end

  describe "custom types" do
    it "works with custom types" do
      get "/custom_types?email= x@Y.Z &phone=555-111-2222&arr=1,2,a"
      expect(last_response).to have_status(200)
      expect(last_response).to have_json_body.that_includes(
        email: "x@y.z",
        phone: "15551112222",
        arr: ["1", "2", "a"],
      )
    end
  end

  describe "role checking" do
    let(:customer) { Webhookdb::Fixtures.customer.create }

    it "passes if the customer has a matching role" do
      customer.add_role(Webhookdb::Role.create(name: "testing"))
      login_as(customer)
      get "/rolecheck"
      expect(last_response).to have_status(200)
    end

    it "errors if no role with that name exists" do
      login_as(customer)
      get "/rolecheck"
      expect(last_response).to have_status(500)
    end

    it "errors if the customer does not have a matching role" do
      Webhookdb::Role.create(name: "testing")
      login_as(customer)
      get "/rolecheck"
      expect(last_response).to have_json_body.that_includes(
        error: {
          message: "Sorry, this action is unavailable.",
          status: 403,
          code: "role_check",
        },
      )
    end
  end
end
