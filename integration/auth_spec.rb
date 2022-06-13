# frozen_string_literal: true

RSpec.describe "auth", :integration do
  let(:password) { Webhookdb::Fixtures::Customers::PASSWORD }

  it "allows me to sign up with a token, and log out" do
    customer = Webhookdb::Fixtures.customer.create
    code = Webhookdb::Fixtures.reset_code(customer:).create

    login_resp = post(
      "/v1/auth",
      body: {email: customer.email, token: code.token},
    )
    expect(login_resp).to party_status(200)

    customer_resp = get("/v1/me")
    expect(customer_resp).to party_status(200)

    logout_resp = post("/v1/auth/logout")
    expect(logout_resp).to party_status(200)
  end

  it "allows me to login via OTP, and logout" do
    customer = Webhookdb::Fixtures.customer.instance

    login_resp = post("/v1/auth", body: {email: customer.email})
    expect(login_resp).to party_status(202)

    customer = Webhookdb::Customer[email: customer.email]
    login_resp = post("/v1/auth/login_otp/#{customer.opaque_id}", body: {value: customer.reset_codes.last.token})
    expect(login_resp).to party_status(200)

    customer_resp = get("/v1/me")
    expect(customer_resp).to party_status(200)

    logout_resp = post("/v1/auth/logout")
    expect(logout_resp).to party_status(200)
  end

  it "can access admin endpoints only if the customer authed as an admin and retains the role" do
    customer = Webhookdb::Fixtures.customer.admin.instance
    auth_customer(customer)

    resp = get("/admin/v1/auth")
    expect(resp).to party_status(200)
    expect(resp).to party_response(match(hash_including(name: customer.name)))

    customer.remove_role(Webhookdb::Role.admin_role)

    resp = get("/admin/v1/auth")
    expect(resp).to party_status(401)
  end
end
