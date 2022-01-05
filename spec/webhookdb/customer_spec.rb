# frozen_string_literal: true

RSpec.describe "Webhookdb::Customer", :db do
  let(:described_class) { Webhookdb::Customer }

  it "can be inspected" do
    expect { Webhookdb::Customer.new.inspect }.to_not raise_error
  end

  describe "greeting" do
    it "uses the name if present" do
      expect(described_class.new(name: "Huck Finn").greeting).to eq("Huck Finn")
    end

    it "uses the default if none can be parsed" do
      expect(described_class.new.greeting).to eq("there")
    end
  end

  context "ensure_role" do
    let(:customer) { Webhookdb::Fixtures.customer.create }
    let(:role) { Webhookdb::Role.create(name: "customer-test") }
    it "can set a role by a role object" do
      customer.ensure_role(role)

      expect(customer.roles).to contain_exactly(role)
    end

    it "can set a role by the role name" do
      customer.ensure_role(role.name)
      expect(customer.roles).to contain_exactly(role)
    end

    it "noops if the customer already has the role" do
      customer.ensure_role(role.name)
      customer.ensure_role(role.name)
      customer.ensure_role(role)
      customer.ensure_role(role)
      expect(customer.roles).to contain_exactly(role)
    end
  end

  describe "authenticate" do
    let(:password) { "testtest1" }

    it "returns true if the password matches" do
      u = Webhookdb::Customer.new
      u.password = password
      expect(u.authenticate(password)).to be_truthy
    end

    it "returns false if the password does not match" do
      u = Webhookdb::Customer.new
      u.password = "testtest1"
      expect(u.authenticate("testtest2")).to be_falsey
    end

    it "returns false if the new password is blank" do
      u = Webhookdb::Customer.new
      expect(u.authenticate(nil)).to be_falsey
      expect(u.authenticate("")).to be_falsey

      space = "          "
      u.password = space
      expect(u.authenticate(space)).to be_truthy
    end

    it "cannot auth after being removed" do
      u = Webhookdb::Fixtures.customer.create
      u.soft_delete
      u.password = password
      expect(u.authenticate(password)).to be_falsey
    end
  end

  describe "setting password" do
    let(:customer) { Webhookdb::Fixtures.customer.instance }

    it "sets the digest to a bcrypt hash" do
      customer.password = "abcdefg123"
      expect(customer.password_digest.to_s).to have_length(described_class::PLACEHOLDER_PASSWORD_DIGEST.to_s.length)
    end

    it "uses the placeholder for a nil password" do
      customer.password = nil
      expect(customer.password_digest).to be === described_class::PLACEHOLDER_PASSWORD_DIGEST
    end

    it "fails if the password is not complex enough" do
      expect { customer.password = "" }.to raise_error(described_class::InvalidPassword)
    end
  end

  describe "::register_or_login" do
    let(:email) { "jane@farmers.org" }
    let(:customer_params) do
      {email:}
    end

    describe "for an email that does not match an existing customer" do
      it "creates a customer" do
        step, c = described_class.register_or_login(**customer_params)
        expect(c).to_not be_nil
        expect(c).to have_attributes(email:)
        expect(step.output).to include("Welcome to WebhookDB")
      end

      it "lowercases the email" do
        step, me = described_class.register_or_login(**customer_params.merge(email: "HEARME@ROAR.coM"))
        expect(me).to have_attributes(email: "hearme@roar.com")
      end

      it "trims spaces from email" do
        step, me = described_class.register_or_login(**customer_params.merge(email: " barf@sb.com "))
        expect(me).to have_attributes(email: "barf@sb.com")
      end

      it "creates a new email reset code for the customer" do
        step, me = described_class.register_or_login(email:)
        new_code = me.refresh.reset_codes.first
        expect(new_code).to_not be_expired
        expect(new_code).to have_attributes(transport: "email")
      end

      it "creates new organization and membership for current customer if doesn't exist" do
        step, me = described_class.register_or_login(email:)

        new_org = Webhookdb::Organization[name: "Org for #{email}"]
        expect(new_org).to_not be_nil
        expect(new_org.billing_email).to eq(email)

        expect(new_org.memberships_dataset.where(customer: me).all).to contain_exactly(have_attributes(status: "admin"))
      end
    end

    describe "for an email matching an existing customer" do
      let!(:customer) { Webhookdb::Fixtures.customer(**customer_params).create }

      it "expires and creates a new email reset code for the customer" do
        existing_code = Webhookdb::Fixtures.reset_code(customer:).email.create

        step, me = described_class.register_or_login(email:)

        expect(me).to be === customer
        expect(existing_code.refresh).to be_expired
        new_code = me.refresh.reset_codes.first
        expect(new_code).to_not be_expired
        expect(new_code).to have_attributes(transport: "email")
        expect(step.output).to include("Welcome back")
      end
    end
  end

  describe "::finish_otp" do
    let(:email) { "jane@farmers.org" }
    let(:opaque_id) { "cus_testing" }
    let(:customer_params) do
      {email:, opaque_id:}
    end
    let!(:customer) { Webhookdb::Fixtures.customer(**customer_params).create }

    it "errors if the opaque id does not belong to an existing customer" do
      step, me = described_class.finish_otp(opaque_id: "cus_nope", token: "abcd")
      expect(me).to be_nil
      expect(step.output).to include("no one with that email")
    end

    it "returns a succesful step and the user" do
      code = customer.add_reset_code(transport: "email")
      default_org = Webhookdb::Fixtures.organization.create
      customer.add_membership(organization: default_org)

      step, me = described_class.finish_otp(opaque_id:, token: code.token)

      expect(me).to be === customer
      expect(step.output).to include("Welcome!")
      expect(code.refresh).to have_attributes(used: true)
    end

    it "fails if the token does not belong to the customer" do
      code = Webhookdb::Fixtures.reset_code.create
      step, me = described_class.finish_otp(opaque_id:, token: code.token)
      expect(me).to be_nil
      expect(step).to have_attributes(error_code: "invalid_otp")
    end

    it "fails if the token is invalid" do
      code = Webhookdb::Fixtures.reset_code(customer:).create
      code.expire!
      step, me = described_class.finish_otp(opaque_id:, token: code.token)
      expect(me).to be_nil
      expect(step).to have_attributes(error_code: "invalid_otp")
    end

    it "logs the user in if the code is invalid and auth skipping is enabled for the customer email" do
      Webhookdb::Customer.skip_authentication_allowlist = ["*@cats.org"]
      customer.update(email: "meow@cats.org")
      step, me = described_class.finish_otp(opaque_id:, token: "a")
      expect(me).to be === customer
    ensure
      Webhookdb::Customer.reset_configuration
    end
  end
end
