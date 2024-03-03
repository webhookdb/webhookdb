# frozen_string_literal: true

require "rack/test"

require "webhookdb/api"

class Webhookdb::API::TestService < Webhookdb::Service
  format :json
  require "webhookdb/service/helpers"
  helpers Webhookdb::Service::Helpers
  include Webhookdb::Service::Types

  get :merror do
    # Ensure merror! sets content type explicitly
    content_type "application/xml"
    merror!(403, "Hello!", code: "test_err", more: {doc_url: "http://some-place"})
  end

  params do
    requires :id
    requires :email
    requires :rollback, type: Boolean
  end
  get :merror_rollback do
    c = Webhookdb::Customer[params[:id]]
    c.db.transaction do
      c.update(email: params[:email])
      merror!(403, "Hello!", rollback_db: params[:rollback] ? c.db : nil)
    end
  end

  post :merror_pass do
    merror!(*params[:args], **params[:kwargs].symbolize_keys)
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

  get :sequel_validation do
    Webhookdb::Fixtures.customer.create(email: "a@b.c")
  end

  get :invalid_plain do
    invalid!("this is invalid")
  end

  get :invalid_array do
    invalid!(["a is invalid", "b is invalid"])
  end

  get :save_or_error do
    c = Webhookdb::Customer.new
    save_or_error!(c)
  end

  params do
    requires :email, type: String, coerce_with: NormalizedEmail
    requires :phone, type: String, coerce_with: NormalizedPhone
    requires :arr, type: [String], coerce_with: CommaSepArray
  end
  get :custom_types do
    present({email: params[:email], phone: params[:phone], arr: params[:arr]})
  end
  params do
    requires :email, type: String, coerce_with: NormalizedEmail
    requires :phone, type: String, coerce_with: NormalizedPhone
    requires :arr, type: [String], coerce_with: CommaSepArray
  end
  post :custom_types do
    status 200
    present({email: params[:email], phone: params[:phone], arr: params[:arr]})
  end

  params do
    optional :phone, us_phone: true
    optional :ident, db_identifier: true
  end
  get :custom_validators do
  end

  get :lock_failed do
    raise Webhookdb::LockFailed
  end

  get :unhandled do
    1 / 0
  end

  get :hello do
    status 201
    body "hi"
  end

  class CustomerEntity < Webhookdb::Service::Entities::Base
    expose :id
    expose :note

    def self.display_headers
      return [[:id, "ID"]]
    end
  end

  get :current_customer do
    c = current_customer
    header "Test-TLS-User-Id", Thread.current[:request_user]&.id&.to_s
    header "Test-TLS-Admin-Id", Thread.current[:request_admin]&.id&.to_s
    present({id: c.id})
  end

  get :collection_array do
    present_collection [1, 2, 3]
  end

  get :collection_dataset do
    present_collection Webhookdb::Customer.dataset, with: CustomerEntity, message: "hello"
  end

  get :collection_direct do
    coll = Webhookdb::Service::Collection.new([5, 6, 7], current_page: 10, page_count: 20, total_count: 3,
                                                         last_page: false,)
    present_collection coll
  end

  get :entity do
    present Webhookdb::Customer.first, with: CustomerEntity, message: "hello"
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

  get :current_customer do
    c = current_customer
    present({id: c.id})
  end

  get :current_customer_safe do
    c = current_customer?
    present({id: c&.id})
  end

  get :admin_customer do
    c = admin_customer
    present({id: c.id})
  end

  get :admin_customer_safe do
    c = admin_customer?
    present({id: c&.id})
  end
end

RSpec.describe Webhookdb::Service, :db do
  include Rack::Test::Methods

  before(:all) do
    @devmode = described_class.devmode
    @enforce_ssl = described_class.enforce_ssl
  end

  after(:all) do
    described_class.devmode = @devmode
    described_class.enforce_ssl = @enforce_ssl
  end

  before(:each) do
    described_class.devmode = true
    described_class.enforce_ssl = false
  end

  let(:app) { Webhookdb::API::TestService.build_app }

  it "redirects requests if SSL is enforced" do
    described_class.enforce_ssl = true

    get "/hello"
    expect(last_response).to have_status(301)
  end

  it "always clears request_user after the request" do
    Thread.current[:request_user] = 5
    Thread.current[:request_admin] = 6
    get "/hello"
    expect(last_response).to have_status(201)
    expect(Thread.current[:request_user]).to be_nil
    expect(Thread.current[:request_admin]).to be_nil

    Thread.current[:request_user] = 5
    Thread.current[:request_admin] = 6
    get "/merror"
    expect(last_response).to have_status(403)
    expect(Thread.current[:request_user]).to be_nil
    expect(Thread.current[:request_admin]).to be_nil
  end

  it "uses a consistent error shape for manual errors (merror!)" do
    get "/merror"
    expect(last_response).to have_status(403)
    expect(last_response_json_body).to eq(
      error: {doc_url: "http://some-place", message: "Hello!", status: 403, code: "test_err"},
    )
  end

  it "rolls back the transaction on merrors", db: :no_transaction do
    c = Webhookdb::Fixtures.customer.create(email: "a@b.co")

    get "/merror_rollback", id: c.id, email: "x@y.zx", rollback: true

    expect(last_response).to have_status(403)
    expect(c.refresh).to have_attributes(email: "a@b.co")
  end

  it "does not roll back transactions by default", db: :no_transaction do
    c = Webhookdb::Fixtures.customer.create(email: "a@b.co")

    get "/merror_rollback", id: c.id, email: "x@y.zx", rollback: false

    expect(last_response).to have_status(403)
    expect(c.refresh).to have_attributes(email: "x@y.zx")
  end

  it "can alert in Sentry", :sentry do
    expect(Sentry).to receive(:capture_message).with("bye")

    post "/merror_pass", args: [400, "hi"], kwargs: {code: "foo"}
    expect(last_response).to have_status(400)

    post "/merror_pass", args: [402, "bye"], kwargs: {alert: true}
    expect(last_response).to have_status(402)
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
        field_errors: {arg1: ["is missing"], arg2: ["is missing"]},
      },
    )

    get "/invalid_password"
    expect(last_response).to have_status(400)
    expect(last_response_json_body).to eq(
      error: {
        code: "validation_error",
        errors: ["password not a bunny"],
        message: "Not a bunny",
        field_errors: {password: ["not a bunny"]},
        status: 400,
      },
    )
  end

  it "uses a consistent error shape for Sequel validation errors" do
    get "/sequel_validation"
    expect(last_response).to have_status(400)
    expect(last_response_json_body).to eq(
      error: {
        code: "validation_error",
        errors: ["email is invalid"],
        message: "Email is invalid",
        field_errors: {email: ["is invalid"]},
        status: 400,
      },
    )

    get "/save_or_error"
    expect(last_response).to have_status(400)
    expect(last_response_json_body).to eq(
      error: {
        code: "validation_error",
        errors: ["email is not present", "email is invalid", "email is not == "],
        message: "Email is not present, email is invalid, email is not == ",
        field_errors: {email: ["is not present", "is invalid", "is not == "]},
        status: 400,
      },
    )
  end

  it "derives a message from a validation error string" do
    get "/invalid_plain"
    expect(last_response).to have_status(400)
    expect(last_response_json_body).to eq(
      error: {
        code: "validation_error",
        errors: ["this is invalid"],
        message: "This is invalid",
        field_errors: {},
        status: 400,
      },
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
        field_errors: {},
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
    Webhookdb::Sentry.dsn = "foo"
    Webhookdb::Sentry.run_after_configured_hooks
    expect(Sentry).to receive(:capture_exception)

    described_class.devmode = false

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
  ensure
    Webhookdb::Sentry.reset_configuration
  end

  it "uses a consistent error shape for unhandled errors (devmode: on)" do
    described_class.devmode = true

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
    described_class.devmode = true

    put "/hello"

    expect(last_response).to have_status(405)
    expect(last_response).to have_json_body.that_includes(error: "405 Not Allowed")
  end

  it "always creates a session for unauthed customers" do
    get "/hello"

    expect(last_response).to have_status(201)
    expect(last_session_id).to be_present
  end

  describe "session length" do
    it "is the default normally" do
      header "Whdb-Short-Session", ""

      get "/hello"

      expect(last_response).to have_status(201)
      cookie = CGI::Cookie.parse(last_response["Set-Cookie"])
      expect(cookie).to include("webhookdb.session")
      expect(Time.parse(cookie["expires"][0])).to be > (10.days.from_now)
    end

    it "is very short if Whdb-Short-Session header is present" do
      header "Whdb-Short-Session", "1"

      get "/hello"

      expect(last_response).to have_status(201)
      cookie = CGI::Cookie.parse(last_response["Set-Cookie"])
      expect(cookie).to include("webhookdb.session")
      expect(Time.parse(cookie["expires"][0])).to be < (2.hours.from_now)
    end
  end

  describe "endpoint caching" do
    after(:all) do
      described_class.endpoint_caching = false
    end

    it "can cache via an Expires header" do
      described_class.endpoint_caching = true

      get "/caching"

      expect(last_response).to have_status(200)
      expect(last_response.headers).to include("Expires", "Cache-Control" => "public")
      expect(Time.parse(last_response.headers["Expires"])).to be_within(1.second).of(5.minutes.from_now)
    end

    it "does not cache if endpoint caching is disabled" do
      described_class.endpoint_caching = false

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

    it "can wrap a Sequel dataset with a real entity" do
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
        display_headers: [["id", "ID"]],
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

  describe "Sentry integration" do
    before(:each) do
      # We need to fake doing what Sentry would be doing for initialization,
      # so we can assert it has the right data in its scope.
      Webhookdb::Sentry.dsn = "foo"
      hub = Sentry::Hub.new(
        Sentry::Client.new(Sentry::Configuration.new),
        Sentry::Scope.new,
      )
      expect(Sentry).to_not be_initialized
      Sentry.instance_variable_set(:@main_hub, hub)
      expect(Sentry).to be_initialized
    end

    after(:each) do
      Webhookdb::Sentry.reset_configuration
      expect(Sentry).to_not be_initialized
    end

    it "reports errors to Sentry if devmode is off and Sentry is enabled" do
      described_class.devmode = false
      expect(Sentry).to receive(:capture_exception).
        with(ZeroDivisionError, tags: include(:error_id, :error_signature))

      get "/unhandled"
      expect(last_response).to have_status(500)
    end

    it "does not report errors to Sentry if devmode is on and Sentry is enabled" do
      described_class.devmode = true
      expect(Sentry).to_not receive(:capture_exception)

      get "/unhandled"
      expect(last_response).to have_status(500)
    end

    it "does not report errors to Sentry if devmode is on and Sentry is disabled" do
      described_class.devmode = true
      Webhookdb::Sentry.reset_configuration
      expect(Sentry).to_not be_initialized
      expect(Sentry).to_not receive(:capture_exception)

      get "/unhandled"
      expect(last_response).to have_status(500)
    end

    it "does not report errors to Sentry if devmode is off and Sentry is disabled" do
      described_class.devmode = false
      Webhookdb::Sentry.reset_configuration
      expect(Sentry).to_not be_initialized
      expect(Sentry).to_not receive(:capture_exception)

      get "/unhandled"
      expect(last_response).to have_status(500)
    end

    it "captures context for unauthed customers" do
      scope = Webhookdb::SpecHelpers::Service::FakeSentryScope.new
      expect(Sentry).to receive(:configure_scope).and_yield(scope)

      get "/hello?world=1"
      expect(last_response).to have_status(201)

      expect(scope).to have_attributes(
        user: include(ip_address: "127.0.0.1"),
        tags: include(host: "example.org", method: "GET", path: "/hello", query: "world=1"),
      )
    end

    it "captures context for authed customers" do
      customer = Webhookdb::Fixtures.customer.create
      login_as(customer)

      scope = Webhookdb::SpecHelpers::Service::FakeSentryScope.new
      expect(Sentry).to receive(:configure_scope).and_yield(scope)

      get "/hello?world=1"
      expect(last_response).to have_status(201)

      expect(scope).to have_attributes(
        user: include(
          ip_address: "127.0.0.1",
          id: customer.id,
          email: customer.email,
          name: customer.name,
        ),
        tags: include(
          host: "example.org",
          method: "GET",
          path: "/hello",
          query: "world=1",
          "customer.email" => customer.email,
        ),
      )
    end

    it "captures context for admins" do
      admin = Webhookdb::Fixtures.customer.admin.create
      customer = Webhookdb::Fixtures.customer.create
      impersonate(admin:, target: customer)

      scope = Webhookdb::SpecHelpers::Service::FakeSentryScope.new
      expect(Sentry).to receive(:configure_scope).and_yield(scope)

      get "/hello?world=1"
      expect(last_response).to have_status(201)

      expect(scope).to have_attributes(
        user: include(
          admin_id: admin.id,
          id: customer.id,
        ),
        tags: include(
          "customer.email" => customer.email,
          "admin.email" => admin.email,
        ),
      )
    end
  end

  describe "etag mixin" do
    it "hashes the rendered entity" do
      get "/etagged"

      expect(last_response).to have_status(200)
      expect(last_response.body).to eq(
        '{"field1":25,"field2":"abcd","x":"2020-04-23","etag":"fd6c113974ee35d9d492e5af75d026c9"}',
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

    it "POST works with custom types" do
      post "/custom_types", {email: " x@Y.Z ", phone: "555-111-2222", arr: "1,2,a"}
      expect(last_response).to have_status(200)
      expect(last_response).to have_json_body.that_includes(
        email: "x@y.z",
        phone: "15551112222",
        arr: ["1", "2", "a"],
      )
    end

    it "POST works with actual arrays" do
      post "/custom_types", {email: " x@Y.Z ", phone: "555-111-2222", arr: ["1", "2", "a"]}
      expect(last_response).to have_status(200)
      expect(last_response).to have_json_body.that_includes(
        email: "x@y.z",
        phone: "15551112222",
        arr: ["1", "2", "a"],
      )
    end
  end

  describe "custom validators" do
    it "can validate a phone" do
      get "/custom_validators?phone=555-111-2222"
      expect(last_response).to have_status(200)

      get "/custom_validators?phone=555-111-22"
      expect(last_response).to have_status(400)
      expect(last_response).to have_json_body.
        that_includes(error: include(message: "Phone must be a 10-digit US phone"))
    end

    it "can validate a db identifier" do
      get "/custom_validators?ident=hello"
      expect(last_response).to have_status(200)

      get "/custom_validators?ident=1"
      expect(last_response).to have_status(400)
      expect(last_response).to have_json_body.that_includes(
        error: include(
          message: /Ident is not a valid database identifier/,
        ),
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
          code: "permission_check",
        },
      )
    end
  end

  describe "current_customer" do
    let(:customer) { Webhookdb::Fixtures.customer.create }
    let(:admin) { Webhookdb::Fixtures.customer.admin.create }

    it "looks up the logged in user" do
      login_as(customer)
      get "/current_customer"
      expect(last_response).to have_status(200)
      expect(last_response).to have_json_body.that_includes(id: customer.id)
    end

    it "sets the custom in thread local and clears it after the request" do
      login_as(customer)
      impersonate(admin:, target: customer)
      get "/current_customer"
      expect(last_response).to have_status(200)
      expect(last_response.headers["Test-TLS-User-Id"]).to eq(customer.id.to_s)
      expect(last_response.headers["Test-TLS-Admin-Id"]).to eq(admin.id.to_s)
      expect(Thread.current[:request_user]).to be_nil
      expect(Thread.current[:request_admin]).to be_nil
    end

    it "errors if no logged in user" do
      get "/current_customer"
      expect(last_response).to have_status(401)
    end

    it "errors and clears cookies if the user is deleted" do
      login_as(customer)
      customer.soft_delete
      get "/current_customer"
      expect(last_response).to have_status(401)
      expect(last_response.cookies).to be_empty
    end

    it "returns the impersonated user (even if deleted)" do
      impersonate(admin:, target: customer)
      get "/current_customer"
      expect(last_response).to have_status(200)
      expect(last_response).to have_json_body.that_includes(id: customer.id)
    end

    it "errors and clears cookies if the admin impersonating a user is deleted" do
      impersonate(admin:, target: customer)
      admin.soft_delete
      get "/current_customer"
      expect(last_response).to have_status(401)
      expect(last_response.cookies).to be_empty
    end

    it "errors if the admin impersonating a user does not have the admin role" do
      impersonate(admin:, target: customer)
      admin.remove_all_roles
      get "/current_customer"
      expect(last_response).to have_status(401)
    end
  end

  describe "current_customer?" do
    let(:customer) { Webhookdb::Fixtures.customer.create }
    let(:admin) { Webhookdb::Fixtures.customer.admin.create }

    it "looks up the logged in user" do
      login_as(customer)
      get "/current_customer_safe"
      expect(last_response).to have_status(200)
      expect(last_response).to have_json_body.that_includes(id: customer.id)
    end

    it "returns nil if no logged in user" do
      get "/current_customer_safe"
      expect(last_response).to have_status(200)
      expect(last_response).to have_json_body.that_includes(id: nil)
    end

    it "errors and clears cookies if the user is deleted" do
      login_as(customer)
      customer.soft_delete
      get "/current_customer_safe"
      expect(last_response).to have_status(401)
    end

    it "returns the impersonated user (even if deleted)" do
      impersonate(admin:, target: customer)
      get "/current_customer_safe"
      expect(last_response).to have_status(200)
      expect(last_response).to have_json_body.that_includes(id: customer.id)
    end

    it "errors if the admin impersonating a user is deleted/missing role" do
      impersonate(admin:, target: customer)
      admin.soft_delete
      get "/current_customer_safe"
      expect(last_response).to have_status(401)
      expect(last_response.cookies).to be_empty
    end
  end

  describe "admin_customer" do
    let(:customer) { Webhookdb::Fixtures.customer.create }
    let(:admin) { Webhookdb::Fixtures.customer.admin.create }

    it "looks up the logged in admin" do
      login_as_admin(admin)
      get "/admin_customer"
      expect(last_response).to have_status(200)
      expect(last_response).to have_json_body.that_includes(id: admin.id)
    end

    it "errors if no logged in admin" do
      get "/admin_customer"
      expect(last_response).to have_status(401)
    end

    it "errors and clears cookies if the admin is deleted" do
      login_as_admin(admin)
      admin.soft_delete
      get "/admin_customer"
      expect(last_response).to have_status(401)
      expect(last_response.cookies).to be_empty
    end

    it "errors and clears cookies if the admin does not have the role" do
      login_as_admin(admin)
      admin.remove_all_roles
      get "/admin_customer"
      expect(last_response).to have_status(401)
      expect(last_response.cookies).to be_empty
    end

    it "returns the admin, even while impersonating" do
      impersonate(admin:, target: customer)
      get "/admin_customer"
      expect(last_response).to have_status(200)
      expect(last_response).to have_json_body.that_includes(id: admin.id)
    end
  end

  describe "admin_customer?" do
    let(:customer) { Webhookdb::Fixtures.customer.create }
    let(:admin) { Webhookdb::Fixtures.customer.admin.create }

    it "looks up the logged in admin" do
      login_as_admin(admin)
      get "/admin_customer_safe"
      expect(last_response).to have_status(200)
      expect(last_response).to have_json_body.that_includes(id: admin.id)
    end

    it "returns nil no logged in admin" do
      get "/admin_customer_safe"
      expect(last_response).to have_status(200)
      expect(last_response).to have_json_body.that_includes(id: nil)
    end

    it "errors and clears cookies if the admin is deleted" do
      login_as_admin(admin)
      admin.soft_delete
      get "/admin_customer_safe"
      expect(last_response).to have_status(401)
      expect(last_response.cookies).to be_empty
    end

    it "errors and clears cookies if the admin does not have the role" do
      login_as_admin(admin)
      admin.remove_all_roles
      get "/admin_customer_safe"
      expect(last_response).to have_status(401)
      expect(last_response.cookies).to be_empty
    end

    it "returns the admin, even while impersonating" do
      impersonate(admin:, target: customer)
      get "/admin_customer_safe"
      expect(last_response).to have_status(200)
      expect(last_response).to have_json_body.that_includes(id: admin.id)
    end
  end

  describe "BaseEntity" do
    describe "timezone helper" do
      let(:obj_class) { Struct.new(:time, :customer, keyword_init: true) }
      let(:t) { Time.parse("2021-09-16T12:41:23Z") }

      it "renders using a path to a timezone" do
        customer_class = Struct.new(:mytz)
        ent = Class.new(Webhookdb::Service::Entities::Base) do
          expose :time, &self.timezone(:customer, :mytz)
        end
        r = ent.represent(obj_class.new(time: t, customer: customer_class.new("America/New_York")))
        expect(r.as_json[:time]).to eq("2021-09-16T08:41:23-04:00")
      end

      it "renders using a path to an object with a :timezone method" do
        ent = Class.new(Webhookdb::Service::Entities::Base) do
          expose :time, &self.timezone(:customer)
        end
        customer_class = Struct.new(:timezone)
        r = ent.represent(obj_class.new(time: t, customer: customer_class.new("America/New_York")))
        expect(r.as_json[:time]).to eq("2021-09-16T08:41:23-04:00")
      end

      it "renders using a path to an object with a :time_zone method" do
        customer_class = Struct.new(:time_zone)
        ent = Class.new(Webhookdb::Service::Entities::Base) do
          expose :time, &self.timezone(:customer)
        end
        r = ent.represent(obj_class.new(time: t, customer: customer_class.new("America/New_York")))
        expect(r.as_json[:time]).to eq("2021-09-16T08:41:23-04:00")
      end

      it "uses the default rendering if any item in the path is missing" do
        ts = t.iso8601
        customer_class = Struct.new(:mytz)
        ent = Class.new(Webhookdb::Service::Entities::Base) do
          expose :time, &self.timezone(:customer, :mytz)
        end

        d = obj_class.new(time: t)
        expect(d).to receive(:customer).and_raise(NoMethodError)
        r = ent.represent(d)
        expect(r.as_json[:time]).to eq(ts)

        d = obj_class.new(time: t, customer: customer_class.new)
        expect(d.customer).to receive(:mytz).and_raise(NoMethodError)
        r = ent.represent(d)
        expect(r.as_json[:time]).to eq(ts)

        d = obj_class.new(time: t, customer: customer_class.new(nil))
        r = ent.represent(d)
        expect(r.as_json[:time]).to eq(ts)

        d = obj_class.new(time: t, customer: customer_class.new(""))
        r = ent.represent(d)
        expect(r.as_json[:time]).to eq(ts)
      end

      it "can pull from an explicit field" do
        ent = Class.new(Webhookdb::Service::Entities::Base) do
          expose :time_not_here, &self.timezone(:customer, field: :mytime)
        end
        obj_class = Struct.new(:mytime, :customer)
        customer_class = Struct.new(:time_zone)
        r = ent.represent(obj_class.new(t, customer_class.new("America/New_York")))
        expect(r.as_json[:time_not_here]).to eq("2021-09-16T08:41:23-04:00")
      end
    end
  end
end
