# frozen_string_literal: true

RSpec.describe "auth", :integration do
  let(:password) { Webhookdb::Fixtures::Customers::PASSWORD }

  it "allows me to sign up" do
    customer = Webhookdb::Fixtures.customer.instance

    login_resp = post(
      "/v1/register",
      body: {
        email: customer.email,
        password:,
        phone: customer.phone,
        timezone: "America/Los_Angeles",
      },
    )
    expect(login_resp).to party_status(200)

    customer_resp = get("/v1/me")
    expect(customer_resp).to party_status(200)
  end

  it "allows me to log in and out" do
    customer = Webhookdb::Fixtures.customer.password(password).create

    login_resp = post("/v1/auth", body: {email: customer.email, password:})
    expect(login_resp).to party_status(200)
    expect(login_resp).to party_response(match(hash_including(name: customer.name)))

    customer_resp = get("/v1/me")
    expect(customer_resp).to party_status(200)

    logout_resp = delete("/v1/auth")
    expect(logout_resp).to party_status(204)
  end

  it "signs me in if I sign up but already have an account with that email/password" do
    customer = Webhookdb::Fixtures.customer.password(password).create

    login_resp = post(
      "/v1/register",
      body: {
        email: customer.email,
        password:,
        name: customer.name,
        phone: customer.phone,
        timezone: "America/Los_Angeles",
      },
    )
    expect(login_resp).to party_status(200)
    expect(login_resp).to party_response(match(hash_including(id: customer.id)))
  end

  it "can forget and reset a password" do
    customer = Webhookdb::Fixtures.customer.create

    forgot_resp = post("/v1/me/forgot_password", body: {email: customer.email})
    expect(forgot_resp).to party_status(202)

    expect(customer.reset_codes).to have_attributes(length: 1)
    token = customer.reset_codes.first

    reset_resp = post("/v1/me/reset_password", body: {token: token.token, password: "test1234reset"})
    expect(reset_resp).to party_status(200)

    get_customer_resp = get("/v1/me")
    expect(get_customer_resp).to party_status(200)
  end

  xit "can access admin endpoints only if the customer authed as an admin and retains the role" do
    customer = Webhookdb::Fixtures.customer.admin.instance
    auth_customer(customer)

    resp = get("/admin/v1/auth")
    expect(resp).to party_status(200)
    expect(resp).to party_response(match(hash_including(name: customer.name)))

    customer.remove_role(Webhookdb::Role.admin_role)

    resp = get("/admin/v1/auth")
    expect(resp).to party_status(403)
  end

  xit "can sudo, re-sudo, and unsudo" do
    admin = Webhookdb::Fixtures.customer.admin.instance
    auth_customer(admin)

    target = Webhookdb::Fixtures.customer.create

    sudo_resp = post("/admin/v1/auth/sudo/#{target.id}")
    expect(sudo_resp).to party_status(200)
    expect(sudo_resp).to party_response(match(hash_including(name: target.name, sudoed: true)))

    get_customer_resp = get("/v1/me")
    expect(get_customer_resp).to party_status(200)
    expect(get_customer_resp).to party_response(match(hash_including(name: target.name, sudoed: true)))

    get_admin_resp = get("/admin/v1/auth")
    expect(get_admin_resp).to party_status(200)
    expect(get_admin_resp).to party_response(match(hash_including(name: admin.name, sudoed: true)))

    other_target = Webhookdb::Fixtures.customer.create
    resudo_resp = post("/admin/v1/auth/sudo/#{other_target.id}")
    expect(resudo_resp).to party_status(200)
    expect(resudo_resp).to party_response(match(hash_including(name: other_target.name, sudoed: true)))

    unsudo_resp = delete("/admin/v1/auth/sudo")
    expect(unsudo_resp).to party_status(200)
    expect(unsudo_resp).to party_response(match(hash_including(name: admin.name, sudoed: false)))

    get_customer2_resp = get("/v1/me")
    expect(get_customer2_resp).to party_status(200)
    expect(get_customer2_resp).to party_response(match(hash_including(name: admin.name, sudoed: false)))
  end

  xit "can sudo a deleted customer" do
    admin = Webhookdb::Fixtures.customer.admin.instance
    auth_customer(admin)

    target = Webhookdb::Fixtures.customer.create
    target.soft_delete

    sudo_resp = post("/admin/v1/auth/sudo/#{target.id}")
    expect(sudo_resp).to party_status(200)
    expect(sudo_resp).to party_response(match(hash_including(name: target.name, sudoed: true)))

    get_customer_resp = get("/v1/me")
    expect(get_customer_resp).to party_status(200)
    expect(get_customer_resp).to party_response(match(hash_including(name: target.name, sudoed: true)))

    get_admin_resp = get("/admin/v1/auth")
    expect(get_admin_resp).to party_status(200)
    expect(get_admin_resp).to party_response(match(hash_including(name: admin.name, sudoed: true)))
  end
end
